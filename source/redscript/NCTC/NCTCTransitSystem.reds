module NCTC

public class NCTCDeferredDriveCommand extends DelayCallback {
  private let bus: wref<VehicleObject>;
  private let controller: wref<NCTCServiceBusController>;
  private let target: Vector4;
  private let minimumDistance: Float;
  private let trafficSpeedLimit: Float;
  private let trafficSpeedProfile: Int32;
  private let forcedStartSpeed: Float;
  private let commandGeneration: Int32;

  public func Configure(bus: ref<VehicleObject>, controller: ref<NCTCServiceBusController>, target: Vector4, minimumDistance: Float, trafficSpeedLimit: Float, trafficSpeedProfile: Int32, forcedStartSpeed: Float, commandGeneration: Int32) -> ref<NCTCDeferredDriveCommand> {
    this.bus = bus;
    this.controller = controller;
    this.target = target;
    this.minimumDistance = minimumDistance;
    this.trafficSpeedLimit = trafficSpeedLimit;
    this.trafficSpeedProfile = trafficSpeedProfile;
    this.forcedStartSpeed = forcedStartSpeed;
    this.commandGeneration = commandGeneration;
    return this;
  }

  public func Call() -> Void {
    let command: ref<AIVehicleDriveToPointCommand>;
    if !IsDefined(this.bus) || !this.bus.IsAttached() || !IsDefined(this.bus.GetAIComponent()) { return; };
    // r372n: callbacks are deferred across frames. If route state changes
    // again before this callback fires, never submit the now-stale command.
    if IsDefined(this.controller) && !this.controller.IsDriveGenerationCurrent(this.commandGeneration) {
      this.controller.ReportStaleDriveCallback(this.commandGeneration);
      return;
    };
    // NCTC-owned traffic command. It uses the game's traffic behavior without
    // consulting ADE settings or activating the player's AutoDrive system.
    command = new AIVehicleDriveToPointCommand();
    command.targetPosition = Vector4.Vector4To3(this.target);
    command.secureTimeOut = 1200.00;
    command.useTraffic = true;
    if Equals(this.trafficSpeedProfile, 5) {
      // r374f: speedInTraffic alone is not a hard vehicle-speed cap.
      // Match the standalone autonomous actuator semantics: the traffic
      // controller keeps its >=8 traffic value while maxSpeed carries the
      // actual requested approach cap.
      command.speedInTraffic = MaxF(this.trafficSpeedLimit, 8.00);
      command.maxSpeed = this.trafficSpeedLimit;
      command.minSpeed = 0.00;
    } else {
      command.speedInTraffic = this.trafficSpeedLimit;
    };
    command.forceGreenLights = false;
    // These must remain false for the service bus. Enabling either one lets
    // the traffic controller snap the long Mahir to a neighboring lane when
    // a route command starts or ends, which can eject standing passengers.
    command.trafficTryNeighborsForStart = false;
    command.trafficTryNeighborsForEnd = false;
    // r372n: standard service commands still use zero completion radius, but
    // rolling handoffs can preserve the actual bus speed on the replacement
    // command. Keep the values on the native object instead of telemetry-only.
    command.minimumDistanceToTarget = this.minimumDistance;
    if this.forcedStartSpeed > 0.50 { command.forcedStartSpeed = this.forcedStartSpeed; };
    // Dev telemetry: proves the exact native stopping threshold carried by
    // the command that was actually sent, rather than inferring it later
    // from ADE's global settings.
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_minimum_distance_mm", Cast<Int32>(this.minimumDistance * 1000.00));
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_speed_limit_x10", Cast<Int32>(this.trafficSpeedLimit * 10.00));
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_speed_profile", this.trafficSpeedProfile);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(this.forcedStartSpeed * 1000.00));
    command.needDriver = false;
    command.driveDownTheRoadIndefinitely = false;
    // SendCommand is the path used by Delamain while V is mounted as a
    // passenger. QueueEvent + SetInitCmd is suitable for an empty traffic
    // vehicle, but PassengerEvents can cancel that initialization on 2.3+.
    this.bus.GetAIComponent().SendCommand(command);
    if IsDefined(this.controller) { this.controller.SetActiveRouteCommand(command, this.commandGeneration); };
  }
}

public class NCTCDeferredBerthDriveCommand extends DelayCallback {
  private let bus: wref<VehicleObject>;
  private let controller: wref<NCTCServiceBusController>;
  private let target: Vector4;
  private let startSpeed: Float;
  private let commandGeneration: Int32;

  public func Configure(bus: ref<VehicleObject>, controller: ref<NCTCServiceBusController>, target: Vector4, startSpeed: Float, commandGeneration: Int32) -> ref<NCTCDeferredBerthDriveCommand> {
    this.bus = bus;
    this.controller = controller;
    this.target = target;
    this.startSpeed = startSpeed;
    this.commandGeneration = commandGeneration;
    return this;
  }

  public func Call() -> Void {
    let command: ref<AIVehicleDriveToPointCommand>;
    if !IsDefined(this.bus) || !this.bus.IsAttached() || !IsDefined(this.bus.GetAIComponent()) { return; };
    if IsDefined(this.controller) && !this.controller.IsDriveGenerationCurrent(this.commandGeneration) {
      this.controller.ReportStaleDriveCallback(this.commandGeneration);
      return;
    };
    command = new AIVehicleDriveToPointCommand();
    command.targetPosition = Vector4.Vector4To3(this.target);
    command.secureTimeOut = 120.00;
    command.useTraffic = false;
    command.maxSpeed = 7.00;
    command.minSpeed = 0.00;
    command.clearTrafficOnPath = false;
    command.minimumDistanceToTarget = 0.00;
    if this.startSpeed > 0.50 { command.forcedStartSpeed = this.startSpeed; };
    command.needDriver = false;
    command.driveDownTheRoadIndefinitely = false;
    this.bus.GetAIComponent().SendCommand(command);
    if IsDefined(this.controller) { this.controller.SetActiveRouteCommand(command, this.commandGeneration); };
  }
}


// NCTC owns the native autonomous command lifecycle. V remains an ordinary
// passenger and no player AutoDrive system participates in service routing.
public class NCTCServiceBusController extends IScriptable {
  private let bus: wref<VehicleObject>;
  private let playerAboardSignal: Bool;
  private let activeRouteCommand: ref<AIVehicleDriveToPointCommand>;
  // Diagnostic-only: retain the command that was active immediately before a
  // route handoff, so the dev log can prove whether it was replaced or left
  // alive alongside the command for the next stop.
  private let previousRouteCommand: ref<AIVehicleDriveToPointCommand>;
  private let driveGeneration: Int32;

  public func Bind(bus: ref<VehicleObject>) -> Bool {
    if !IsDefined(bus) || !IsDefined(bus.GetAIComponent()) { return false; };
    this.bus = bus;
    this.bus.GetVehiclePS().SetIsPlayerVehicle(false);
    GameInstance.GetGodModeSystem(this.bus.GetGame()).AddGodMode(this.bus.GetEntityID(), gameGodModeType.Invulnerable, n"NCTCServiceBus");
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_service_bus_invulnerable", 1);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37413);
    return true;
  }

  public func IsReady() -> Bool { return IsDefined(this.bus) && this.bus.IsAttached(); }

  public func GetWorldPosition() -> Vector4 {
    return this.IsReady() ? this.bus.GetWorldPosition() : new Vector4(0.00, 0.00, 0.00, 0.00);
  }

  public func GetWorldForward() -> Vector4 {
    return this.IsReady() ? Vector4.Normalize2D(this.bus.GetWorldForward()) : new Vector4(0.00, 0.00, 0.00, 0.00);
  }

  public func GetCurrentSpeed() -> Float {
    return this.IsReady() ? this.bus.GetCurrentSpeed() : -1.00;
  }

  public func IsNear(position: Vector4, radius: Float) -> Bool {
    return this.IsReady() && Vector4.Distance(this.bus.GetWorldPosition(), position) <= radius;
  }

  // A berth is an oriented service line, not a large circular area. The bus
  // must cross the gate while it is moving; NCTC then cancels the route and
  // lets the vehicle stop. Requiring zero speed here would make the trigger
  // unreachable, since movement is what carries the pivot across the berth.
  public func IsAtBerth(position: Vector4, out longitudinal: Float, out lateral: Float, out speed: Float) -> Bool {
    let delta: Vector4;
    let forward: Vector4;
    let right: Vector4;
    if !this.IsReady() { return false; };
    delta = position - this.bus.GetWorldPosition();
    forward = Vector4.Normalize2D(this.bus.GetWorldForward());
    right = Vector4.Normalize2D(this.bus.GetWorldRight());
    longitudinal = Vector4.Dot(delta, forward);
    lateral = AbsF(Vector4.Dot(delta, right));
    speed = AbsF(this.bus.GetCurrentSpeed());
    // Broad enough for a 0.5-second service poll at traffic speed, but
    // directional: it cannot trigger merely because the bus is nearby.
    return longitudinal <= 4.00 && longitudinal >= -6.00 && lateral <= 3.00;
  }

  public func IsPlayerAboard() -> Bool {
    let player: ref<PlayerPuppet>;
    let mounted: ref<VehicleObject>;
    if !this.IsReady() { return false; };
    if this.playerAboardSignal { return true; };
    player = GetPlayer(this.bus.GetGame());
    if !IsDefined(player) { return false; };
    // The rear passenger workspots are mounted by the CET cabin module.
    // Depending on the current vehicle state, the vanilla mounting helpers do
    // not always expose that workspot immediately. The cabin module publishes
    // the exact service-bus match every frame, so use it as the authoritative
    // departure signal and keep the native checks as fallbacks.
    if Equals(GameInstance.GetQuestsSystem(this.bus.GetGame()).GetFact(n"nctc_player_in_service_bus"), 1) { return true; };
    if VehicleComponent.IsMountedToProvidedVehicle(this.bus.GetGame(), player.GetEntityID(), this.bus) { return true; };
    mounted = player.GetMountedVehicle();
    return IsDefined(mounted) && Equals(mounted.GetEntityID(), this.bus.GetEntityID());
  }

  public func SetPlayerAboardSignal(value: Bool) -> Void {
    this.playerAboardSignal = value;
  }

  public func DistanceToPlayer() -> Float {
    let player: ref<PlayerPuppet>;
    if !this.IsReady() { return 0.00; };
    player = GetPlayer(this.bus.GetGame());
    return IsDefined(player) ? Vector4.Distance(player.GetWorldPosition(), this.bus.GetWorldPosition()) : 0.00;
  }

  public func DriveToTraffic(target: Vector4, minimumDistance: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let speedProfile: Int32;
    let speedLimit: Float;
    let generation: Int32;
    if !this.IsReady() { return false; };
    generation = this.NextDriveGeneration();
    // Every new traffic leg needs the native NoDriver -> DriverReady state
    // transition, including while V is aboard. Without it the command object
    // remains Active but the vehicle controller stays idle after a service
    // stop. ADE applies the same workaround after passenger/seat transitions.
    this.PrepareBusForTrafficDrive();
    callback = new NCTCDeferredDriveCommand();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(this.bus, this, target, minimumDistance, speedLimit, speedProfile, 0.00, generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.25, false);
    return true;
  }

  // r372n rolling passage handoff. The passage command is deliberately aimed
  // far down the road AFTER the waypoint, so it is still pulling the Mahir
  // forward when NCTC changes legs. Only then do we interrupt it, pulse the
  // native driver lifecycle over separate frames, and submit the successor
  // with the measured rolling speed.
  public func DriveToTrafficAfterRollingPassage(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let speedProfile: Int32;
    let speedLimit: Float;
    let generation: Int32;
    if !this.IsReady() { return false; };

    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.activeRouteCommand = null;

    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00));

    callback = new NCTCDeferredDriveCommand();
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(this.bus, this, target, minimumDistance, speedLimit, speedProfile, MaxF(startSpeed, 0.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }

  // r374e: generation-safe traffic replacement, but unlike r372n the
  // successor intentionally does NOT inherit the rolling speed. A braking
  // command cannot simultaneously be forced to start at the previous 14–16 m/s.
  // It remains useTraffic=true with a 7.0 approach speed.
  public func DriveToTrafficAtSpeed(target: Vector4, minimumDistance: Float, startSpeed: Float, speedLimit: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let generation: Int32;
    if !this.IsReady() { return false; };

    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.activeRouteCommand = null;

    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00));

    callback = new NCTCDeferredDriveCommand();
    callback.Configure(this.bus, this, target, minimumDistance, speedLimit, 5, MaxF(startSpeed, 0.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }

  // r373a: keep normal traffic navigation for the route, then hand the last
  // metres to the autonomous point driver so the Mahir may leave the traffic
  // lane and enter a surveyed bus bay / berth.
  public func DriveToBerthDirect(target: Vector4, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredBerthDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let generation: Int32;
    if !this.IsReady() { return false; };
    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.activeRouteCommand = null;
    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    callback = new NCTCDeferredBerthDriveCommand();
    callback.Configure(this.bus, this, target, MaxF(startSpeed, 0.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }

  // Adaptive NCTC service speed. The game district supplies the zone profile
  // while long uninterrupted legs receive a small arterial/highway bonus.
  // This only changes the per-command traffic target: vehicle physics and the
  // traffic controller's obstacle/lane logic remain vanilla.
  private func ResolveTrafficSpeed(target: Vector4, out profile: Int32) -> Float {
    let settings: ref<NCTCSettings> = NCTCSettings.Get(this.bus.GetGame());
    let prevention: ref<PreventionSystem>;
    let district: ref<District>;
    let record: wref<District_Record>;
    let recordId: TweakDBID;
    let depth: Int32 = 0;
    let speed: Float = 50.00;
    let hardCeiling: Float = 80.00;
    let legDistance: Float;

    profile = 0;

    if IsDefined(settings) {
      speed = Cast<Float>(settings.fallbackTrafficSpeed);
      hardCeiling = Cast<Float>(settings.absoluteTrafficSpeedCeiling);
      if !settings.adaptiveTrafficSpeed {
        if speed > hardCeiling { speed = hardCeiling; };
        return speed;
      };
    };

    prevention = GameInstance.GetScriptableSystemsContainer(this.bus.GetGame()).Get(NameOf<PreventionSystem>()) as PreventionSystem;
    if IsDefined(prevention) {
      district = prevention.GetCurrentDistrict();
      if IsDefined(district) {
        record = district.GetDistrictRecord();
      };
    };

    while IsDefined(record) && depth < 8 {
      recordId = record.GetID();

      if Equals(recordId, t"Districts.Badlands") {
        profile = 4;
        speed = IsDefined(settings) ? Cast<Float>(settings.badlandsTrafficSpeed) : 70.00;
        break;
      };

      if Equals(recordId, t"Districts.CityCenter") || Equals(recordId, t"Districts.Dogtown") {
        profile = 1;
        speed = IsDefined(settings) ? Cast<Float>(settings.denseCityTrafficSpeed) : 45.00;
        break;
      };

      if Equals(recordId, t"Districts.SantoDomingo") || Equals(recordId, t"Districts.Pacifica") {
        profile = 3;
        speed = IsDefined(settings) ? Cast<Float>(settings.outerCityTrafficSpeed) : 55.00;
        break;
      };

      if Equals(recordId, t"Districts.Watson") || Equals(recordId, t"Districts.Westbrook") || Equals(recordId, t"Districts.Heywood") {
        profile = 2;
        speed = IsDefined(settings) ? Cast<Float>(settings.cityTrafficSpeed) : 50.00;
        break;
      };

      record = record.ParentDistrict();
      depth += 1;
    };

    // Approximate road class without replacing the game's traffic navigation:
    // very long service legs are typically arterials, ring roads or Badlands
    // roads. Passage waypoints naturally split difficult urban legs, so they
    // do not accidentally receive the long-road bonus.
    legDistance = Vector4.Distance(this.bus.GetWorldPosition(), target);
    if legDistance > 1800.00 {
      speed += 10.00;
    } else {
      if legDistance > 1000.00 {
        speed += 5.00;
      };
    };

    if speed > hardCeiling { speed = hardCeiling; };
    return speed;
  }

  private func PrepareBusForTrafficDrive() -> Void {
    let noDriver: ref<AIEvent> = new AIEvent();
    let driverReady: ref<AIEvent> = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.10);
  }

  private func NextDriveGeneration() -> Int32 {
    this.driveGeneration += 1;
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_drive_generation", this.driveGeneration);
    return this.driveGeneration;
  }

  public func IsDriveGenerationCurrent(generation: Int32) -> Bool {
    return Equals(generation, this.driveGeneration);
  }

  public func ReportStaleDriveCallback(generation: Int32) -> Void {
    let quests: ref<QuestsSystem>;
    if !this.IsReady() { return; };
    quests = GameInstance.GetQuestsSystem(this.bus.GetGame());
    quests.SetFact(n"nctc_dev_stale_drive_generation", generation);
    quests.SetFact(n"nctc_dev_stale_drive_callback_id", quests.GetFact(n"nctc_dev_stale_drive_callback_id") + 1);
  }

  public func SetActiveRouteCommand(command: ref<AIVehicleDriveToPointCommand>, generation: Int32) -> Void {
    if !this.IsDriveGenerationCurrent(generation) { return; };
    this.activeRouteCommand = command;
  }

  public func IsRouteCommandSuccessful() -> Bool {
    return IsDefined(this.activeRouteCommand) && Equals(this.activeRouteCommand.state, AICommandState.Success);
  }

  // Telemetry only. The command state is exposed so the dev runtime can prove
  // whether the native controller completes, replaces, or leaves our command active.
  public func GetRouteCommandStatusCode() -> Int32 {
    if !IsDefined(this.activeRouteCommand) { return 0; };
    if Equals(this.activeRouteCommand.state, AICommandState.Success) { return 2; };
    if Equals(this.activeRouteCommand.state, AICommandState.Failure)
      || Equals(this.activeRouteCommand.state, AICommandState.Cancelled)
      || Equals(this.activeRouteCommand.state, AICommandState.Interrupted) { return 3; };
    return 1;
  }

  public func GetPreviousRouteCommandStatusCode() -> Int32 {
    if !IsDefined(this.previousRouteCommand) { return 0; };
    if Equals(this.previousRouteCommand.state, AICommandState.Success) { return 2; };
    if Equals(this.previousRouteCommand.state, AICommandState.Failure)
      || Equals(this.previousRouteCommand.state, AICommandState.Cancelled)
      || Equals(this.previousRouteCommand.state, AICommandState.Interrupted) { return 3; };
    return 1;
  }

  public func IsRouteCommandFailed() -> Bool {
    if !IsDefined(this.activeRouteCommand) { return false; };
    return Equals(this.activeRouteCommand.state, AICommandState.Failure)
      || Equals(this.activeRouteCommand.state, AICommandState.Cancelled)
      || Equals(this.activeRouteCommand.state, AICommandState.Interrupted);
  }

  public func IsStoppedNear(position: Vector4, radius: Float) -> Bool {
    return this.IsReady() && AbsF(this.bus.GetCurrentSpeed()) <= 0.50 && this.IsNear(position, radius);
  }

  public func CancelTrafficRoute() -> Void {
    if this.IsReady() {
      this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    };
  }

  public func ArriveAtStop() -> Void {
    if !this.IsReady() { return; };
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
  }

  // The Mahir coach door is stateful. The old working prototype did not rely
  // on VehicleComponent.OpenDoor alone: it sent VehicleDoorOpen directly to
  // the VehiclePS and retried until that persistent state became Open.
  public func KeepPassengerDoorOpen() -> Void {
    if !this.IsReady() { return; };
    if NotEquals(this.bus.GetVehiclePS().GetDoorState(EVehicleDoor.seat_front_right), VehicleDoorState.Open) {
      this.QueuePassengerDoorOpen();
    };
  }

  private func QueuePassengerDoorOpen() -> Void {
    let event: ref<VehicleDoorOpen>;
    let ps: ref<VehicleComponentPS>;
    if !this.IsReady() { return; };
    ps = this.bus.GetVehiclePS();
    if !IsDefined(ps) { return; };
    event = new VehicleDoorOpen();
    event.slotID = n"seat_front_right";
    event.forceScene = false;
    ps.QueuePSEvent(ps, event);
  }

  public func ClosePassengerDoor() -> Void {
    let slot: MountingSlotId;
    let event: ref<VehicleDoorClose>;
    let ps: ref<VehicleComponentPS>;
    if !this.IsReady() { return; };
    slot.id = n"seat_front_right";
    VehicleComponent.CloseDoor(this.bus, slot);
    ps = this.bus.GetVehiclePS();
    if IsDefined(ps) {
      event = new VehicleDoorClose();
      event.slotID = n"seat_front_right";
      event.forceScene = false;
      ps.QueuePSEvent(ps, event);
    };
  }

  public func IsPassengerDoorClosed() -> Bool {
    return this.IsReady() && Equals(this.bus.GetVehiclePS().GetDoorState(EVehicleDoor.seat_front_right), VehicleDoorState.Closed);
  }

  public func IsPassengerDoorOpen() -> Bool {
    return this.IsReady() && Equals(this.bus.GetVehiclePS().GetDoorState(EVehicleDoor.seat_front_right), VehicleDoorState.Open);
  }

  public func StartPlayerAutoDriveTo(target: Vector4, out waypoint: NewMappinID) -> Bool {
    let data: MappinData;
    let mappins: ref<MappinSystem>;
    if !this.IsReady() || !this.IsPlayerAboard() { return false; };
    mappins = GameInstance.GetMappinSystem(this.bus.GetGame());
    if !IsDefined(mappins) { return false; };
    data.mappinType = t"Mappins.DefaultStaticMappin";
    data.variant = gamedataMappinVariant.CustomPositionVariant;
    data.active = true;
    data.debugCaption = "NCTC next stop";
    waypoint = mappins.RegisterMappin(data, target);
    return this.DriveToTraffic(target, 0.00);
  }
}

public class NCTCServiceProfiles {
  // Diagnostic-only bridge. It records how the sequence resolver interpreted
  // the currently published network; it never participates in route control.
  private static func PublishSequenceProbe(game: GameInstance, code: Int32, line: Int32, currentStopId: Int32, currentSequence: Int32, nextStopId: Int32, nextSequence: Int32, stopCount: Int32) -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_dev_sequence_probe_code", code);
    quests.SetFact(n"nctc_dev_sequence_probe_line", line);
    quests.SetFact(n"nctc_dev_sequence_probe_current_id", currentStopId);
    quests.SetFact(n"nctc_dev_sequence_probe_current_sequence", currentSequence);
    quests.SetFact(n"nctc_dev_sequence_probe_next_id", nextStopId);
    quests.SetFact(n"nctc_dev_sequence_probe_next_sequence", nextSequence);
    quests.SetFact(n"nctc_dev_sequence_probe_count", stopCount);
    quests.SetFact(n"nctc_dev_sequence_probe_id", quests.GetFact(n"nctc_dev_sequence_probe_id") + 1);
  }

  // Same rule for capture profiles: expose the exact validity facts that
  // decide whether the successor can receive a traffic command.
  public static func PublishProfileProbe(game: GameInstance, stopId: Int32) -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let prefix: String = "nctc_external_capture_id" + ToString(stopId) + "_";
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_dev_profile_probe_stop_id", stopId);
    quests.SetFact(n"nctc_dev_profile_probe_spawn_valid", quests.GetFact(StringToName(prefix + "spawn_valid")));
    quests.SetFact(n"nctc_dev_profile_probe_approach_valid", quests.GetFact(StringToName(prefix + "approach_valid")));
    quests.SetFact(n"nctc_dev_profile_probe_berth_valid", quests.GetFact(StringToName(prefix + "berth_valid")));
    quests.SetFact(n"nctc_dev_profile_probe_spawn_x_mm", quests.GetFact(StringToName(prefix + "spawn_x")));
    quests.SetFact(n"nctc_dev_profile_probe_spawn_y_mm", quests.GetFact(StringToName(prefix + "spawn_y")));
    quests.SetFact(n"nctc_dev_profile_probe_berth_x_mm", quests.GetFact(StringToName(prefix + "berth_x")));
    quests.SetFact(n"nctc_dev_profile_probe_berth_y_mm", quests.GetFact(StringToName(prefix + "berth_y")));
    quests.SetFact(n"nctc_dev_profile_probe_id", quests.GetFact(n"nctc_dev_profile_probe_id") + 1);
  }

  public static func TryGet(game: GameInstance, line: String, stopId: Int32, out spawn: Vector4, out approach: Vector4, out berth: Vector4, out yaw: Float) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let requestedLine: Int32 = StringToInt(line, -1);
    let prefix: String;
    if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_external_network_ready"), 1) { return false; };
    if stopId < 1 { return false; };
    prefix = "nctc_external_capture_id" + ToString(stopId) + "_";
    if !Equals(quests.GetFact(StringToName(prefix + "spawn_valid")), 1) || !Equals(quests.GetFact(StringToName(prefix + "berth_valid")), 1) { return false; };
    spawn = NCTCServiceProfiles.ReadVector(quests, prefix + "spawn_");
    approach = NCTCServiceProfiles.ReadVector(quests, prefix + "approach_");
    berth = NCTCServiceProfiles.ReadVector(quests, prefix + "berth_");
    // A profile can be observed while CET is republishing its validity facts
    // but before all coordinate facts are restored. Never route a vehicle to
    // the world origin, which manifests in game as an unexplained U-turn.
    if AbsF(spawn.X) < 1.00 && AbsF(spawn.Y) < 1.00 { return false; };
    if AbsF(berth.X) < 1.00 && AbsF(berth.Y) < 1.00 { return false; };
    yaw = Cast<Float>(quests.GetFact(StringToName(prefix + "spawn_yaw"))) / 1000.00;
    return true;
  }

  // The berth's forward direction is recorded alongside its position by the
  // developer survey. It is deliberately separate from spawn yaw: one is
  // spawn orientation, the other is the direction in which traffic passes
  // through the service stop.
  public static func TryGetBerthForward(game: GameInstance, stopId: Int32, out forward: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let prefix: String = "nctc_external_capture_id" + ToString(stopId) + "_berth_";
    if !IsDefined(quests) || !Equals(quests.GetFact(StringToName(prefix + "forward_valid")), 1) { return false; };
    forward = new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "forward_x"))) / 1000000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "forward_y"))) / 1000000.00, 0.00, 0.00);
    forward = Vector4.Normalize2D(forward);
    return AbsF(forward.X) > 0.01 || AbsF(forward.Y) > 0.01;
  }


  public static func TryGetNextStop(game: GameInstance, line: String, currentStopId: Int32, out nextStopId: Int32, out nextStop: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let requestedLine: Int32 = StringToInt(line, -1);
    let count: Int32;
    let index: Int32 = 0;
    let stopLine: Int32;
    let stopId: Int32;
    let currentIndex: Int32 = -1;
    let firstIndex: Int32 = -1;
    let firstId: Int32 = 0;
    let firstPosition: Vector4;
    let currentFound: Bool = false;
    let prefix: String;
    if !IsDefined(quests) || requestedLine < 1 || !Equals(quests.GetFact(n"nctc_external_network_ready"), 1) {
      NCTCServiceProfiles.PublishSequenceProbe(game, 1, requestedLine, currentStopId, -1, 0, -1, 0);
      return false;
    };
    count = quests.GetFact(n"nctc_external_network_stop_count");
    // The JSON stops array is the authored service order. IDs stay stable for
    // survey captures, but must not decide where a line goes next: deleting
    // or recreating a stop deliberately leaves its ID unrelated to its order.
    while index < count {
      prefix = "nctc_external_stop_" + ToString(index) + "_";
      stopLine = quests.GetFact(StringToName(prefix + "line"));
      stopId = quests.GetFact(StringToName(prefix + "id"));
      if Equals(stopLine, requestedLine) {
        if firstId < 1 {
          firstId = stopId;
          firstPosition = NCTCServiceProfiles.ReadVector(quests, prefix);
          firstIndex = index;
        };
        if currentFound {
          nextStopId = stopId;
          nextStop = NCTCServiceProfiles.ReadVector(quests, prefix);
          NCTCServiceProfiles.PublishSequenceProbe(game, nextStopId > 0 ? 3 : 4, requestedLine, currentStopId, currentIndex, nextStopId, index, count);
          return nextStopId > 0;
        };
        if Equals(stopId, currentStopId) {
          currentFound = true;
          currentIndex = index;
        };
      };
      index += 1;
    };
    if currentFound && firstId > 0 {
      nextStopId = firstId;
      nextStop = firstPosition;
      NCTCServiceProfiles.PublishSequenceProbe(game, 5, requestedLine, currentStopId, currentIndex, nextStopId, firstIndex, count);
      return true;
    };
    NCTCServiceProfiles.PublishSequenceProbe(game, currentFound ? 6 : 2, requestedLine, currentStopId, currentIndex, 0, -1, count);
    return false;
  }

  private static func ReadVector(quests: ref<QuestsSystem>, prefix: String) -> Vector4 {
    return new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "x"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "y"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "z"))) / 1000.00, 1.00);
  }

  // Passage points are traffic-only waypoints associated with the leg after
  // an authored stop. They are not stops and never open doors or dwell.
  public static func TryGetPassageAfter(game: GameInstance, line: String, afterStopId: Int32, ordinal: Int32, out passage: Vector4, out forward: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let requestedLine: Int32 = StringToInt(line, -1);
    let count: Int32;
    let index: Int32 = 0;
    let matched: Int32 = 0;
    let prefix: String;
    if !IsDefined(quests) || requestedLine < 1 || afterStopId < 1 || !Equals(quests.GetFact(n"nctc_external_network_ready"), 1) { return false; };
    count = quests.GetFact(n"nctc_external_network_passage_count");
    while index < count {
      prefix = "nctc_external_passage_" + ToString(index) + "_";
      if Equals(quests.GetFact(StringToName(prefix + "line")), requestedLine)
        && Equals(quests.GetFact(StringToName(prefix + "after_stop_id")), afterStopId) {
        if Equals(matched, ordinal) {
          passage = NCTCServiceProfiles.ReadVector(quests, prefix);
          forward = new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "forward_x"))) / 1000000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "forward_y"))) / 1000000.00, 0.00, 0.00);
          if !Equals(quests.GetFact(StringToName(prefix + "forward_valid")), 1) { forward = new Vector4(0.00, 0.00, 0.00, 0.00); }
          else { forward = Vector4.Normalize2D(forward); };
          return AbsF(passage.X) > 1.00 || AbsF(passage.Y) > 1.00;
        };
        matched += 1;
      };
      index += 1;
    };
    return false;
  }
}

public class NCTCServiceDispatchCallback extends DelayCallback {
  private let system: wref<NCTCTransitSystem>;
  public func Configure(system: ref<NCTCTransitSystem>) -> Void { this.system = system; }
  public func Call() -> Void { if IsDefined(this.system) { this.system.UpdateRequestedService(); }; }
}

// Runtime owner for exactly one summoned service bus.
public class NCTCTransitSystem extends ScriptableSystem {
  private let busEntityID: EntityID;
  private let requestedLine: String;
  private let requestedStopId: Int32;
  // A route point is always visited in sequence. This separate value decides
  // whether that visit becomes a passenger service stop (doors + dwell) or a
  // pass-through point. Calling a bus reserves its current stop initially.
  private let serviceStopId: Int32;
  private let requestedStop: Vector4;
  private let requestPending: Bool;
  private let controller: ref<NCTCServiceBusController>;
  private let driveCommandSent: Bool;
  private let arrived: Bool;
  private let hasSurveyProfile: Bool;
  private let surveySpawn: Vector4;
  private let surveyApproach: Vector4;
  private let surveyBerth: Vector4;
  private let surveyBerthForward: Vector4;
  private let surveyYaw: Float;
  private let approachCommandSent: Bool;
  private let routeStarted: Bool;
  private let dwellPolls: Int32;
  private let boardingDoorWasOpen: Bool;
  private let routeWaypoint: NewMappinID;
  private let departureRequested: Bool;
  private let legPolls: Int32;
  private let telemetryPolls: Int32;
  private let followingPassage: Bool;
  private let berthManeuverActive: Bool;
  private let berthManeuverStage: Int32;
  // r374m: latched once a foreign vehicle is detected inside the authored bay.
  // The stop is then served from the traffic lane and no direct bay command
  // is allowed for the remainder of that stop.
  private let berthBypassActive: Bool;
  // r374g: one short autonomous braking segment on the road before bay entry.
  private let approachSlowdownApplied: Bool;
  private let approachBrakeTarget: Vector4;
  // r374h: signed road offset captured once when the slow bay merge begins.
  // Keeping this fixed prevents the virtual merge target from drifting as the
  // bus changes heading. r374k also reuses the captured road line to arc back
  // out of the bay immediately on departure.
  private let berthMergeSignedLateral: Float;
  private let departureManeuverActive: Bool;
  private let departureStart: Vector4;
  private let departureForward: Vector4;
  private let departureRoadTarget: Vector4;
  private let passageAfterStopId: Int32;
  private let passageOrdinal: Int32;
  private let passageTarget: Vector4;
  private let passageForward: Vector4;
  private let passageForwardRecorded: Bool;

  private func GetServiceBerth() -> Vector4 {
    return this.hasSurveyProfile ? this.surveyBerth : this.requestedStop;
  }

  // r373e: one surveyed berth defines the whole off-lane bay corridor.
  // The berth yaw/forward gives the desired final bus orientation, so the
  // player does not need to author separate entry and parking points.
  private func GetBerthForward() -> Vector4 {
    let forward: Vector4 = this.surveyBerthForward;
    if AbsF(forward.X) > 0.01 || AbsF(forward.Y) > 0.01 {
      return Vector4.Normalize2D(forward);
    };
    if IsDefined(this.controller) {
      return this.controller.GetWorldForward();
    };
    return new Vector4(0.00, 0.00, 0.00, 0.00);
  }

  // r374k: keep the successful early-nose entry, but delay ALIGN until the rear
  // is much farther into the bay. Keep 35% lateral residue at 6 m before berth.
  private func GetBerthEntryTarget() -> Vector4 {
    let forward: Vector4 = this.GetBerthForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    return this.GetServiceBerth()
      - forward * 6.00
      - right * this.berthMergeSignedLateral * 0.35;
  }

  // r374m: one continuous bay target. Keep a small 10% residue on the ROAD
  // side of the berth axis so the direct driver never has a reason to cross
  // the axis and counter-steer back (the visible Cannery/Delamain zigzag).
  private func GetBerthCorridorTarget() -> Vector4 {
    let forward: Vector4 = this.GetBerthForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    return this.GetServiceBerth()
      + forward * 4.00
      - right * this.berthMergeSignedLateral * 0.10;
  }

  // r374k departure: steer out hard from the bus actual stopped position.
  // Target roughly twice the measured road offset, capped at 6 m.
  private func ArmDepartureManeuver() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let forward: Vector4 = this.GetBerthForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let exitLateral: Float;
    this.departureStart = this.controller.GetWorldPosition();
    this.departureForward = forward;
    exitLateral = -this.berthMergeSignedLateral * 2.00;
    if exitLateral > 6.00 { exitLateral = 6.00; };
    if exitLateral < -6.00 { exitLateral = -6.00; };
    this.departureRoadTarget = this.departureStart
      + forward * 10.00
      + right * exitLateral;
    this.departureManeuverActive = true;
    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_departure_target_x_mm", Cast<Int32>(this.departureRoadTarget.X * 1000.00));
      quests.SetFact(n"nctc_dev_departure_target_y_mm", Cast<Int32>(this.departureRoadTarget.Y * 1000.00));
      quests.SetFact(n"nctc_dev_departure_target_z_mm", Cast<Int32>(this.departureRoadTarget.Z * 1000.00));
      quests.SetFact(n"nctc_dev_departure_progress_mm", 0);
      quests.SetFact(n"nctc_dev_departure_speed_mm", 0);
    };
  }

  private func GetDepartureProgress() -> Float {
    let delta: Vector4 = this.controller.GetWorldPosition() - this.departureStart;
    return Vector4.Dot(delta, this.departureForward);
  }

  // r374g: braking target on the current road line. Preserve the signed
  // lateral offset from the berth axis and move only longitudinally to 25 m
  // before the berth. The direct driver can therefore decelerate without
  // immediately cutting into the bay.
  private func GetApproachBrakeTarget() -> Vector4 {
    let forward: Vector4 = this.GetBerthForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let delta: Vector4 = this.GetServiceBerth() - this.controller.GetWorldPosition();
    let signedLateral: Float = Vector4.Dot(delta, right);
    return this.GetServiceBerth() - forward * 25.00 - right * signedLateral;
  }

  // Positive longitudinal means the real berth is still ahead of the bus.
  // Lateral is measured against the surveyed berth axis, not the bus heading.
  private func GetBerthProgress(out lateral: Float) -> Float {
    let forward: Vector4 = this.GetBerthForward();
    let delta: Vector4 = this.GetServiceBerth() - this.controller.GetWorldPosition();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    lateral = AbsF(Vector4.Dot(delta, right));
    return Vector4.Dot(delta, forward);
  }

  private func GetActiveBerthTarget() -> Vector4 {
    if Equals(this.berthManeuverStage, 1) { return this.GetBerthEntryTarget(); };
    if Equals(this.berthManeuverStage, 2) { return this.GetBerthCorridorTarget(); };
    return this.GetServiceBerth();
  }

  // The native Mahir controller settles the pivot before the target. Aim the
  // traffic command beyond the real berth, using its surveyed travel vector,
  // so that this native stop lands at the passenger-service point in one pass.
  private func GetTrafficTarget() -> Vector4 {
    let target: Vector4 = this.GetServiceBerth();
    if this.followingPassage {
      // r372n: a passage is not an endpoint. Aim a full 100 m down the
      // surveyed outgoing road so the native controller has no reason to
      // brake while the bus crosses the waypoint and the handoff zone.
      if AbsF(this.passageForward.X) > 0.01 || AbsF(this.passageForward.Y) > 0.01 { return this.passageTarget + this.passageForward * 100.00; };
      return this.passageTarget;
    };
    if AbsF(this.surveyBerthForward.X) > 0.01 || AbsF(this.surveyBerthForward.Y) > 0.01 {
      return target + this.surveyBerthForward * 13.70;
    };
    return target;
  }

  // A passage yaw is authored as the direction of the ROAD AFTER the
  // waypoint. r371 discarded that information and rebuilt a vector toward the
  // final stop; at junctions that points off the actual lane and makes the AI
  // treat the passage as a destination. Keep the recorded road tangent when
  // available, and use the old onward-vector calculation only as compatibility
  // fallback for legacy yaw-less passages.
  private func ResolvePassageForward() -> Void {
    let nextPassage: Vector4;
    let ignoredRecordedForward: Vector4;
    let onwardTarget: Vector4 = this.GetServiceBerth();
    let onward: Vector4;
    if !this.followingPassage { return; };
    this.passageForwardRecorded = AbsF(this.passageForward.X) > 0.01 || AbsF(this.passageForward.Y) > 0.01;
    if this.passageForwardRecorded {
      this.passageForward = Vector4.Normalize2D(this.passageForward);
      return;
    };
    if NCTCServiceProfiles.TryGetPassageAfter(this.GetGameInstance(), this.requestedLine, this.passageAfterStopId, this.passageOrdinal + 1, nextPassage, ignoredRecordedForward) {
      onwardTarget = nextPassage;
    };
    onward = onwardTarget - this.passageTarget;
    onward.Z = 0.00;
    onward.W = 0.00;
    if AbsF(onward.X) > 0.01 || AbsF(onward.Y) > 0.01 {
      this.passageForward = Vector4.Normalize2D(onward);
    } else {
      this.passageForward = new Vector4(0.00, 0.00, 0.00, 0.00);
    };
  }

  // Signed distance along the surveyed outgoing passage tangent. Negative is
  // before the waypoint, positive is after it. Lateral is the cross-track
  // error to keep an unrelated nearby road from triggering the handoff.
  private func GetPassageProgress(out lateral: Float) -> Float {
    let delta: Vector4;
    let right: Vector4;
    if !this.followingPassage || !IsDefined(this.controller) {
      lateral = 9999.00;
      return -9999.00;
    };
    delta = this.controller.GetWorldPosition() - this.passageTarget;
    delta.Z = 0.00;
    delta.W = 0.00;
    right = new Vector4(-this.passageForward.Y, this.passageForward.X, 0.00, 0.00);
    lateral = AbsF(Vector4.Dot(delta, right));
    return Vector4.Dot(delta, this.passageForward);
  }


  // r374m occupancy bridge. The dev CET scanner only answers whether a
  // foreign vehicle occupies this oriented berth rectangle; routing decisions
  // remain in REDscript.
  private func PublishBerthOccupancyProbe(quests: ref<QuestsSystem>) -> Void {
    let berth: Vector4;
    let forward: Vector4;
    if !IsDefined(quests) { return; };
    if this.serviceStopId <= 0 || !this.hasSurveyProfile {
      quests.SetFact(n"nctc_dev_service_berth_stop_id", 0);
      return;
    };
    berth = this.GetServiceBerth();
    forward = this.GetBerthForward();
    quests.SetFact(n"nctc_dev_service_berth_stop_id", this.serviceStopId);
    quests.SetFact(n"nctc_dev_service_berth_x_mm", Cast<Int32>(berth.X * 1000.00));
    quests.SetFact(n"nctc_dev_service_berth_y_mm", Cast<Int32>(berth.Y * 1000.00));
    quests.SetFact(n"nctc_dev_service_berth_z_mm", Cast<Int32>(berth.Z * 1000.00));
    quests.SetFact(n"nctc_dev_service_berth_forward_x_mm", Cast<Int32>(forward.X * 1000.00));
    quests.SetFact(n"nctc_dev_service_berth_forward_y_mm", Cast<Int32>(forward.Y * 1000.00));
  }

  private func PublishRouteDisplay(nextStopId: Int32) -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let lineNumber: Int32 = StringToInt(this.requestedLine, -1);
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_display_line", lineNumber);
    quests.SetFact(n"nctc_display_next_stop_id", nextStopId);
    // Reserved for the passenger-request visual state. The display remains
    // focused on route information: line number and next stop only.
    quests.SetFact(n"nctc_display_stop_requested", 0);
    quests.SetFact(n"nctc_display_revision", quests.GetFact(n"nctc_display_revision") + 1);
  }

  private func PublishLoopDiagnostic(code: Int32, nextStopId: Int32) -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let busPosition: Vector4;
    let targetPosition: Vector4 = this.GetServiceBerth();
    let trafficTarget: Vector4 = this.GetTrafficTarget();
    let berthActiveTarget: Vector4 = this.GetActiveBerthTarget();
    let berthLateral: Float = 0.00;
    let berthLongitudinal: Float = 0.00;
    let berthHeadingDot: Float = 0.00;
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_dev_loop_code", code);
    quests.SetFact(n"nctc_dev_loop_line", StringToInt(this.requestedLine, -1));
    quests.SetFact(n"nctc_dev_loop_stop_id", this.requestedStopId);
    // The reserved passenger-service stop is intentionally separate from the
    // route's current stop. Publish both so a pass-through can be diagnosed
    // without guessing which ID was lost.
    quests.SetFact(n"nctc_dev_loop_service_stop_id", this.serviceStopId);
    quests.SetFact(n"nctc_dev_loop_next_stop_id", nextStopId);
    quests.SetFact(n"nctc_dev_loop_target_x_mm", Cast<Int32>(targetPosition.X * 1000.00));
    quests.SetFact(n"nctc_dev_loop_target_y_mm", Cast<Int32>(targetPosition.Y * 1000.00));
    quests.SetFact(n"nctc_dev_loop_target_z_mm", Cast<Int32>(targetPosition.Z * 1000.00));
    quests.SetFact(n"nctc_dev_loop_ai_target_x_mm", Cast<Int32>(trafficTarget.X * 1000.00));
    quests.SetFact(n"nctc_dev_loop_ai_target_y_mm", Cast<Int32>(trafficTarget.Y * 1000.00));
    quests.SetFact(n"nctc_dev_loop_ai_target_z_mm", Cast<Int32>(trafficTarget.Z * 1000.00));
    quests.SetFact(n"nctc_dev_loop_berth_longitudinal_mm", 0);
    quests.SetFact(n"nctc_dev_loop_berth_lateral_mm", 0);
    quests.SetFact(n"nctc_dev_loop_berth_speed_mm", 0);
    quests.SetFact(n"nctc_dev_loop_berth_stage", this.berthManeuverStage);
    quests.SetFact(n"nctc_dev_loop_berth_active", this.berthManeuverActive ? 1 : 0);
    quests.SetFact(n"nctc_dev_loop_berth_active_target_x_mm", Cast<Int32>(berthActiveTarget.X * 1000.00));
    quests.SetFact(n"nctc_dev_loop_berth_active_target_y_mm", Cast<Int32>(berthActiveTarget.Y * 1000.00));
    quests.SetFact(n"nctc_dev_loop_berth_active_target_z_mm", Cast<Int32>(berthActiveTarget.Z * 1000.00));
    quests.SetFact(n"nctc_dev_loop_berth_heading_dot_x1000", 0);
    quests.SetFact(n"nctc_dev_loop_berth_merge_lateral_mm", Cast<Int32>(this.berthMergeSignedLateral * 1000.00));
    // Diagnostics only: record exactly why a service stop is about to leave.
    // These facts do not participate in the route decision.
    quests.SetFact(n"nctc_dev_loop_dwell_polls", this.dwellPolls);
    quests.SetFact(n"nctc_dev_loop_player_aboard", IsDefined(this.controller) && this.controller.IsPlayerAboard() ? 1 : 0);
    quests.SetFact(n"nctc_dev_loop_mount_request", quests.GetFact(n"nctc_passenger_departure_requested"));
    if IsDefined(this.controller) && this.controller.IsReady() {
      busPosition = this.controller.GetWorldPosition();
      quests.SetFact(n"nctc_dev_loop_bus_x_mm", Cast<Int32>(busPosition.X * 1000.00));
      quests.SetFact(n"nctc_dev_loop_bus_y_mm", Cast<Int32>(busPosition.Y * 1000.00));
      quests.SetFact(n"nctc_dev_loop_bus_z_mm", Cast<Int32>(busPosition.Z * 1000.00));
      quests.SetFact(n"nctc_dev_loop_target_distance_mm", Cast<Int32>(Vector4.Distance(busPosition, targetPosition) * 1000.00));
      if this.hasSurveyProfile {
        berthLongitudinal = this.GetBerthProgress(berthLateral);
        berthHeadingDot = Vector4.Dot(Vector4.Normalize2D(this.controller.GetWorldForward()), this.GetBerthForward());
        quests.SetFact(n"nctc_dev_loop_berth_longitudinal_mm", Cast<Int32>(berthLongitudinal * 1000.00));
        quests.SetFact(n"nctc_dev_loop_berth_lateral_mm", Cast<Int32>(berthLateral * 1000.00));
        quests.SetFact(n"nctc_dev_loop_berth_speed_mm", Cast<Int32>(AbsF(this.controller.GetCurrentSpeed()) * 1000.00));
        quests.SetFact(n"nctc_dev_loop_berth_heading_dot_x1000", Cast<Int32>(berthHeadingDot * 1000.00));
      };
    };
    quests.SetFact(n"nctc_dev_loop_id", quests.GetFact(n"nctc_dev_loop_id") + 1);
  }

  private func PublishRouteCommandTelemetry() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_dev_command_state", this.controller.GetRouteCommandStatusCode());
    quests.SetFact(n"nctc_dev_previous_command_state", this.controller.GetPreviousRouteCommandStatusCode());
    quests.SetFact(n"nctc_dev_command_speed_mm", Cast<Int32>(this.controller.GetCurrentSpeed() * 1000.00));
    this.PublishLoopDiagnostic(36, this.requestedStopId);
  }

  public static func Get(game: GameInstance) -> ref<NCTCTransitSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<NCTCTransitSystem>()) as NCTCTransitSystem;
  }

  // The cabin runtime publishes a fact while V is standing in the service
  // bus.  Collision hooks additionally verify this exact entity ID, so an
  // unrelated traffic vehicle can never lose its normal impact behaviour.
  public func IsActiveServiceBus(entityID: EntityID) -> Bool {
    return EntityID.IsDefined(this.busEntityID) && Equals(this.busEntityID, entityID);
  }

  public func RequestService(line: String, stopId: Int32, stop: Vector4) -> Bool {
    let quests: ref<QuestsSystem>;
    let spawnDistance: Float;
    let player: ref<PlayerPuppet>;
    if this.requestPending { return false; };
    // Dynamic entities can be invalidated by a load/streaming transition
    // while their EntityID survives in this scriptable system. Treat that as
    // no bus, rather than permanently rejecting every later terminal press.
    if EntityID.IsDefined(this.busEntityID) {
      if this.ResolveBus() { return false; };
      this.busEntityID = new EntityID();
      this.controller = null;
    };
    // A summoned service is meaningful only with both a road spawn and a
    // berth.  Previously an incomplete dev capture still spawned a generic
    // bus ahead of V, then routed it to the stop marker.  That bus could never
    // reach a valid service-arrival state, so its doors stayed closed.
    this.surveyBerthForward = new Vector4(0.00, 0.00, 0.00, 0.00);
    this.hasSurveyProfile = NCTCServiceProfiles.TryGet(this.GetGameInstance(), line, stopId, this.surveySpawn, this.surveyApproach, this.surveyBerth, this.surveyYaw);
    NCTCServiceProfiles.TryGetBerthForward(this.GetGameInstance(), stopId, this.surveyBerthForward);
    quests = GameInstance.GetQuestsSystem(this.GetGameInstance());
    player = GetPlayer(this.GetGameInstance());
    if !this.hasSurveyProfile {
      if IsDefined(quests) {
        quests.SetFact(n"nctc_dev_service_session", quests.GetFact(n"nctc_dev_service_session") + 1);
        quests.SetFact(n"nctc_dev_dispatch_line", StringToInt(line, -1));
        quests.SetFact(n"nctc_dev_dispatch_stop_id", stopId);
        quests.SetFact(n"nctc_dev_dispatch_has_profile", 0);
        quests.SetFact(n"nctc_dev_dispatch_spawn_distance_mm", -1000);
        quests.SetFact(n"nctc_dev_dispatch_id", quests.GetFact(n"nctc_dev_dispatch_id") + 1);
      };
      return false;
    };
    this.requestedLine = line;
    this.requestedStopId = stopId;
    this.serviceStopId = stopId;
    this.requestedStop = stop;
    // A newly summoned bus must begin with the stop that was explicitly
    // requested. Passage state belongs only to a leg already in progress;
    // otherwise a stale point from the previous service can replace this
    // first berth target and make the bus drive in the opposite direction.
    this.followingPassage = false;
    this.passageAfterStopId = 0;
    this.passageOrdinal = 0;
    this.passageTarget = new Vector4(0.00, 0.00, 0.00, 0.00);
    this.passageForward = new Vector4(0.00, 0.00, 0.00, 0.00);
    // Until the bus is on its way to the following stop, its public display
    // identifies the service being called and the boarding stop.
    this.PublishRouteDisplay(stopId);
    this.requestPending = true;
    this.arrived = false;
    GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(n"nctc_service_bus_at_stop", 0);
    this.driveCommandSent = false;
    this.approachCommandSent = false;
    this.boardingDoorWasOpen = false;
    this.departureRequested = false;
    this.berthManeuverActive = false;
    this.berthManeuverStage = 0;
    this.berthBypassActive = false;
    this.berthMergeSignedLateral = 0.00;
    this.departureManeuverActive = false;
    this.approachSlowdownApplied = false;
    this.legPolls = 0;
    GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(n"nctc_passenger_departure_requested", 0);
    // Development-only diagnostic bridge. CET writes this to nctc_survey.log;
    // it never creates a player-facing notification and is absent from public builds.
    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_service_session", quests.GetFact(n"nctc_dev_service_session") + 1);
      spawnDistance = this.hasSurveyProfile && IsDefined(player) ? Vector4.Distance(this.surveySpawn, player.GetWorldPosition()) : -1.00;
      quests.SetFact(n"nctc_dev_dispatch_line", StringToInt(line, -1));
      quests.SetFact(n"nctc_dev_dispatch_stop_id", stopId);
      quests.SetFact(n"nctc_dev_dispatch_has_profile", this.hasSurveyProfile ? 1 : 0);
      quests.SetFact(n"nctc_dev_dispatch_spawn_distance_mm", Cast<Int32>(spawnDistance * 1000.00));
      quests.SetFact(n"nctc_dev_dispatch_id", quests.GetFact(n"nctc_dev_dispatch_id") + 1);
    };
    this.ScheduleDispatch(0.50);
    return true;
  }

  public func GetApproachingLine() -> String {
    if (this.requestPending || EntityID.IsDefined(this.busEntityID)) && !this.arrived {
      return this.requestedLine;
    };
    return "";
  }

  // Developer tooling: release the dynamic entity and reset every state that
  // could otherwise reject the next terminal request as an already-active bus.
  public func DespawnServiceBus() -> Bool {
    let entitySystem: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let hadBus: Bool = EntityID.IsDefined(this.busEntityID) || this.requestPending;
    if hadBus { this.PublishLoopDiagnostic(37, this.requestedStopId); };
    if EntityID.IsDefined(this.busEntityID) && IsDefined(entitySystem) { entitySystem.DeleteEntity(this.busEntityID); };
    this.busEntityID = new EntityID();
    this.controller = null;
    this.requestPending = false;
    this.driveCommandSent = false;
    this.approachCommandSent = false;
    this.routeStarted = false;
    this.dwellPolls = 0;
    this.boardingDoorWasOpen = false;
    this.departureRequested = false;
    this.departureManeuverActive = false;
    this.berthBypassActive = false;
    this.legPolls = 0;
    GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(n"nctc_passenger_departure_requested", 0);
    this.ClearRouteWaypoint();
    this.arrived = false;
    GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(n"nctc_service_bus_at_stop", 0);
    this.hasSurveyProfile = false;
    this.routeStarted = false;
    this.dwellPolls = 0;
    return hadBus;
  }

  private func ScheduleDispatch(delay: Float) -> Void {
    let callback: ref<NCTCServiceDispatchCallback> = new NCTCServiceDispatchCallback();
    callback.Configure(this);
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, delay, false);
  }

  // Direct CET bridge used by the passenger-seat module. Passenger workspots
  // on the Mahir are not reported consistently by the vanilla mounted-vehicle
  // helpers, so the module that performs the mount is the authoritative source.
  public func SetPlayerAboard(value: Bool) -> Void {
    if IsDefined(this.controller) {
      this.controller.SetPlayerAboardSignal(value);
    };
  }

  private func ClearRouteWaypoint() -> Void {
    let mappins: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
    if IsDefined(mappins) && IsDefined(mappins.GetMappin(this.routeWaypoint)) {
      mappins.UnregisterMappin(this.routeWaypoint);
    };
  }

  // Dynamic entities become available one or more frames after CreateEntity,
  // therefore command dispatch is deferred and retries only while requested.
  public func UpdateRequestedService() -> Void {
    let boarded: Bool;
    let quests: ref<QuestsSystem>;
    if this.requestPending {
      // Right after loading a save the dynamic entity system can briefly be
      // unavailable. Do not silently abandon the request: retry until the
      // bus entity has actually been created.
      if !this.SpawnRequestedService() {
        this.ScheduleDispatch(0.25);
        return;
      };
    };
    if !EntityID.IsDefined(this.busEntityID) { return; };
    if !this.ResolveBus() { this.ScheduleDispatch(0.25); return; };
    quests = GameInstance.GetQuestsSystem(this.GetGameInstance());
    this.PublishBerthOccupancyProbe(quests);

    // Stop state: open for passengers, leave as soon as V boards, or after a
    // maximum ten-second dwell when nobody takes this service.
    if this.arrived {
      quests.SetFact(n"nctc_service_bus_at_stop", 1);
      this.controller.KeepPassengerDoorOpen();
      boarded = this.controller.IsPlayerAboard()
        || Equals(quests.GetFact(n"nctc_passenger_departure_requested"), 1);
      // Always leave enough time for the door animation to be visible.
      if this.dwellPolls < 8 {
        this.dwellPolls += 1;
        this.ScheduleDispatch(0.25);
        return;
      };
      if !boarded && this.dwellPolls < 40 {
        this.dwellPolls += 1;
        this.ScheduleDispatch(0.25);
        return;
      };

      quests.SetFact(n"nctc_passenger_departure_requested", 0);
      quests.SetFact(n"nctc_service_bus_at_stop", 0);
      this.controller.ClosePassengerDoor();
      // r374m: no hand-authored departure arc. After closing the doors,
      // immediately return the Mahir to native traffic navigation.
      this.serviceStopId = 0;
      this.departureManeuverActive = false;
      if !this.AdvanceToNextStop() {
        this.PublishLoopDiagnostic(34, 0);
        this.ScheduleDispatch(1.00);
        return;
      };
      this.arrived = false;
      this.dwellPolls = 0;
      this.legPolls = 0;
      this.driveCommandSent = this.controller.DriveToTraffic(this.GetTrafficTarget(), 0.00);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 49 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.25);
      return;
    };

    if !this.driveCommandSent {
      this.driveCommandSent = this.controller.DriveToTraffic(this.GetTrafficTarget(), 0.00);
      this.legPolls = 0;
      this.telemetryPolls = 0;
      this.PublishLoopDiagnostic(this.followingPassage ? 41 : 29, this.requestedStopId);
      this.ScheduleDispatch(0.25);
      return;
    };

    // r374m: departure is now entirely native traffic recovery.

    this.legPolls += 1;
    // Every five seconds, log the exact state of the command object NCTC
    // submitted to the native AI. This is diagnostic-only and distinguishes
    // command completion from a vehicle that merely stopped in traffic.
    this.telemetryPolls += 1;
    if this.telemetryPolls >= 10 {
      this.telemetryPolls = 0;
      this.PublishRouteCommandTelemetry();
    };
    // r372n: cross the passage on one long outgoing-road command. Handoff is
    // deliberately AFTER the waypoint, while the first command still has
    // ~80 m of corridor ahead and the bus therefore retains normal throttle.
    if this.followingPassage && this.passageForwardRecorded {
      let passageLateral: Float;
      let passageProgress: Float = this.GetPassageProgress(passageLateral);
      if passageProgress >= 20.00 && passageLateral <= 12.00 {
        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
        quests.SetFact(n"nctc_dev_passage_progress_mm", Cast<Int32>(passageProgress * 1000.00));
        quests.SetFact(n"nctc_dev_passage_lateral_mm", Cast<Int32>(passageLateral * 1000.00));
        quests.SetFact(n"nctc_dev_passage_handoff_speed_mm", Cast<Int32>(rollingSpeed * 1000.00));
        if !this.AdvancePassageOrDestination() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToTrafficAfterRollingPassage(this.GetTrafficTarget(), 0.00, rollingSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 42 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
    };
    // Compatibility path for an old passage with no authored yaw. This keeps
    // r371 behavior rather than inventing an outgoing road tangent.
    if this.followingPassage && !this.passageForwardRecorded && this.controller.IsNear(this.passageTarget, 15.00) {
      this.controller.CancelTrafficRoute();
      if !this.AdvancePassageOrDestination() {
        this.PublishLoopDiagnostic(34, 0);
        this.ScheduleDispatch(1.00);
        return;
      };
      this.legPolls = 0;
      this.driveCommandSent = this.controller.DriveToTraffic(this.GetTrafficTarget(), 0.00);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 31 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.25);
      return;
    };
    // r374m: occupied bay => remain in traffic mode and serve from the road.
    if !this.followingPassage && this.hasSurveyProfile && !this.berthBypassActive
      && Equals(this.requestedStopId, this.serviceStopId)
      && this.controller.IsNear(this.GetServiceBerth(), 60.00)
      && Equals(quests.GetFact(n"nctc_dev_berth_occupancy_stop_id"), this.serviceStopId)
      && Equals(quests.GetFact(n"nctc_dev_berth_occupied"), 1) {
      this.berthBypassActive = true;
      this.approachSlowdownApplied = false;
      this.berthManeuverActive = false;
      this.berthManeuverStage = 0;
      this.PublishLoopDiagnostic(50, this.requestedStopId);
    };

    // r374g: traffic-mode speed fields proved non-authoritative. Once the bus
    // is close AND already roughly parallel to the berth corridor, hand a
    // short road-aligned segment to the direct driver purely to shed speed.
    // The target remains at the bus' current lateral road offset.
    if !this.followingPassage && this.hasSurveyProfile && !this.berthManeuverActive
      && !this.berthBypassActive
      && Equals(this.requestedStopId, this.serviceStopId)
      && !this.approachSlowdownApplied {
      let brakeLateral: Float;
      let brakeLongitudinal: Float = this.GetBerthProgress(brakeLateral);
      let brakeSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
      if brakeLongitudinal <= 50.00 && brakeLongitudinal >= 20.00
        && brakeLateral <= 8.00 && brakeSpeed > 8.00 {
        this.approachSlowdownApplied = true;
        this.approachBrakeTarget = this.GetApproachBrakeTarget();
        this.legPolls = 0;
        // Zero forcedStartSpeed is intentional: this command exists to brake.
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.approachBrakeTarget, 0.00);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 47 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
    };

    // r374m single-command bay entry: no ENTRY->ALIGN retarget.
    if !this.followingPassage && this.hasSurveyProfile && !this.berthManeuverActive
      && !this.berthBypassActive
      && Equals(this.requestedStopId, this.serviceStopId)
      && this.controller.IsNear(this.GetServiceBerth(), 35.00)
      && (AbsF(this.controller.GetCurrentSpeed()) >= 1.50 || this.approachSlowdownApplied)
      && AbsF(this.controller.GetCurrentSpeed()) <= 8.00 {
      let berthEntrySpeed: Float = AbsF(this.controller.GetCurrentSpeed());
      let berthEntryLateral: Float;
      let berthEntryLongitudinal: Float = this.GetBerthProgress(berthEntryLateral);
      if berthEntryLongitudinal > 0.50 {
        let berthForward: Vector4 = this.GetBerthForward();
        let berthRight: Vector4 = new Vector4(-berthForward.Y, berthForward.X, 0.00, 0.00);
        let berthDelta: Vector4 = this.GetServiceBerth() - this.controller.GetWorldPosition();
        this.berthMergeSignedLateral = Vector4.Dot(berthDelta, berthRight);
        this.berthManeuverActive = true;
        this.berthManeuverStage = 2;
        this.approachSlowdownApplied = false;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBerthCorridorTarget(), berthEntrySpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 43 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
    };

    // r374m: keep the single corridor command alive through arrival.
    // r374h used to cancel it around 8-10 m from the berth and issue a new
    // direct command to the exact berth. That extra native command lifecycle
    // could visibly snap/reposition the long Mahir. The +4 m corridor target
    // now remains authoritative until the normal 7 m stopped-near check below.
    // The AI target is offset beyond the berth. Service remains tied to the
    // real berth, where the Mahir pivot settles in one continuous approach.
    if this.controller.IsStoppedNear(this.GetServiceBerth(), this.berthBypassActive ? 12.00 : 7.00) {
      if Equals(this.requestedStopId, this.serviceStopId) {
        this.controller.ArriveAtStop();
        this.arrived = true;
        this.berthManeuverActive = false;
        this.berthManeuverStage = 0;
        // r374m: preserve stop state through dwell; successor reset follows.
        this.approachSlowdownApplied = false;
        this.driveCommandSent = false;
        this.dwellPolls = 0;
        quests.SetFact(n"nctc_service_bus_at_stop", 1);
        this.controller.KeepPassengerDoorOpen();
        this.PublishLoopDiagnostic(30, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      // Intermediate route point: it has been reached in order, but no one
      // requested service there. Replace the completed command immediately
      // so the bus continues without doors or a dwell state. SendCommand does
      // not replace an in-flight autonomous drive command by itself: the
      // old command remains active and can hold the bus at this stop. End it
      // before the deferred command for the next berth is submitted.
      this.controller.CancelTrafficRoute();
      if !this.AdvanceToNextStop() {
        this.PublishLoopDiagnostic(34, 0);
        this.ScheduleDispatch(1.00);
        return;
      };
      this.legPolls = 0;
      this.driveCommandSent = this.controller.DriveToTraffic(this.GetTrafficTarget(), 0.00);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 31 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.25);
      return;
    };
    if this.controller.IsRouteCommandFailed() {
      this.PublishLoopDiagnostic(35, this.requestedStopId);
      if this.berthManeuverActive {
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetActiveBerthTarget(), AbsF(this.controller.GetCurrentSpeed()));
        this.ScheduleDispatch(0.10);
        return;
      };
      this.driveCommandSent = false;
      this.ScheduleDispatch(0.50);
      return;
    };
    this.ScheduleDispatch(this.followingPassage ? 0.10 : 0.50);
  }

  private func AdvanceToNextStop() -> Bool {
    let nextStopId: Int32;
    let nextStop: Vector4;
    let nextSpawn: Vector4;
    let nextApproach: Vector4;
    let nextBerth: Vector4;
    let nextYaw: Float;
    let previousStopId: Int32 = this.requestedStopId;
    if !NCTCServiceProfiles.TryGetNextStop(this.GetGameInstance(), this.requestedLine, previousStopId, nextStopId, nextStop) {
      this.PublishLoopDiagnostic(4, 0);
      return false;
    };
    NCTCServiceProfiles.PublishProfileProbe(this.GetGameInstance(), nextStopId);
    if !NCTCServiceProfiles.TryGet(this.GetGameInstance(), this.requestedLine, nextStopId, nextSpawn, nextApproach, nextBerth, nextYaw) {
      this.PublishLoopDiagnostic(5, nextStopId);
      return false;
    };
    this.requestedStopId = nextStopId;
    this.requestedStop = nextStop;
    this.surveySpawn = nextSpawn;
    this.surveyApproach = nextApproach;
    this.surveyBerth = nextBerth;
    this.surveyBerthForward = new Vector4(0.00, 0.00, 0.00, 0.00);
    NCTCServiceProfiles.TryGetBerthForward(this.GetGameInstance(), nextStopId, this.surveyBerthForward);
    this.surveyYaw = nextYaw;
    this.hasSurveyProfile = true;
    this.arrived = false;
    this.driveCommandSent = false;
    this.approachCommandSent = false;
    this.berthManeuverActive = false;
    this.berthManeuverStage = 0;
    this.berthBypassActive = false;
    this.berthMergeSignedLateral = 0.00;
    this.approachSlowdownApplied = false;
    this.routeStarted = true;
    this.dwellPolls = 0;
    this.boardingDoorWasOpen = false;
    this.legPolls = 0;
    this.passageForward = new Vector4(0.00, 0.00, 0.00, 0.00);
    this.passageForwardRecorded = false;
    this.followingPassage = NCTCServiceProfiles.TryGetPassageAfter(this.GetGameInstance(), this.requestedLine, previousStopId, 0, this.passageTarget, this.passageForward);
    this.passageAfterStopId = previousStopId;
    this.passageOrdinal = 0;
    this.ResolvePassageForward();
    this.PublishRouteDisplay(nextStopId);
    this.PublishLoopDiagnostic(6, nextStopId);
    return true;
  }

  private func AdvancePassageOrDestination() -> Bool {
    let nextPassage: Vector4;
    let nextOrdinal: Int32 = this.passageOrdinal + 1;
    if NCTCServiceProfiles.TryGetPassageAfter(this.GetGameInstance(), this.requestedLine, this.passageAfterStopId, nextOrdinal, nextPassage, this.passageForward) {
      this.passageOrdinal = nextOrdinal;
      this.passageTarget = nextPassage;
      this.passageForwardRecorded = false;
      this.ResolvePassageForward();
      return true;
    };
    this.followingPassage = false;
    this.passageForwardRecorded = false;
    return true;
  }

  public func SpawnRequestedService() -> Bool {
    let record: ref<Vehicle_Record>;
    let spec: ref<DynamicEntitySpec>;
    let entitySystem: ref<DynamicEntitySystem>;
    let player: ref<PlayerPuppet>;
    let rotation: EulerAngles;
    if !this.requestPending { return false; };
    // A save may restore before CET has republished the external JSON into
    // quest facts. Resolve again at actual entity creation, not only when the
    // player pressed the terminal, so the fresh persisted profile wins.
    this.surveyBerthForward = new Vector4(0.00, 0.00, 0.00, 0.00);
    this.hasSurveyProfile = NCTCServiceProfiles.TryGet(this.GetGameInstance(), this.requestedLine, this.requestedStopId, this.surveySpawn, this.surveyApproach, this.surveyBerth, this.surveyYaw);
    NCTCServiceProfiles.TryGetBerthForward(this.GetGameInstance(), this.requestedStopId, this.surveyBerthForward);
    entitySystem = GameInstance.GetDynamicEntitySystem();
    player = GetPlayer(this.GetGameInstance());
    record = TweakDBInterface.GetVehicleRecord(t"Vehicle.nctc_service_mahir_mt28_coach");
    if !IsDefined(entitySystem) || !entitySystem.IsReady() || !IsDefined(player) || !IsDefined(record) { return false; };
    spec = new DynamicEntitySpec();
    spec.recordID = t"Vehicle.nctc_service_mahir_mt28_coach";
    spec.templatePath = record.EntityTemplatePath();
    spec.appearanceName = record.AppearanceName();
    // First service test: off-screen, short approach. Per-stop road-lane
    // survey data replaces this generic approach in the next pass.
    spec.position = this.hasSurveyProfile ? this.surveySpawn : player.GetWorldPosition() + Vector4.Normalize(player.GetWorldForward()) * 100.00;
    if this.hasSurveyProfile { rotation.Yaw = this.surveyYaw; spec.orientation = EulerAngles.ToQuat(rotation); }
    else { spec.orientation = player.GetWorldOrientation(); };
    spec.persistState = false;
    spec.persistSpawn = false;
    spec.alwaysSpawned = true;
    spec.spawnInView = false;
    spec.active = true;
    spec.tags = [n"NCTC.ServiceBus"];
    this.busEntityID = entitySystem.CreateEntity(spec);
    if !EntityID.IsDefined(this.busEntityID) { return false; };
    this.requestPending = false;
    return true;
  }

  private func ResolveBus() -> Bool {
    let entitySystem: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let entity: ref<Entity>;
    let bus: ref<VehicleObject>;
    if IsDefined(this.controller) && this.controller.IsReady() { return true; };
    if !IsDefined(entitySystem) || !entitySystem.IsSpawned(this.busEntityID) { return false; };
    entity = entitySystem.GetEntity(this.busEntityID);
    bus = entity as VehicleObject;
    if !IsDefined(bus) { return false; };
    if !IsDefined(this.controller) { this.controller = new NCTCServiceBusController(); };
    return this.controller.Bind(bus);
  }
}
