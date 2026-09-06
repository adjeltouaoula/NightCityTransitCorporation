module NCTC
import AutoDriveEnhanced.*

public class NCTCDeferredDriveCommand extends DelayCallback {
  private let bus: wref<VehicleObject>;
  private let controller: wref<NCTCServiceBusController>;
  private let target: Vector4;

  public func Configure(bus: ref<VehicleObject>, controller: ref<NCTCServiceBusController>, target: Vector4) -> ref<NCTCDeferredDriveCommand> {
    this.bus = bus;
    this.controller = controller;
    this.target = target;
    return this;
  }

  public func Call() -> Void {
    let command: ref<AIVehicleDriveToPointCommand>;
    let settings: ref<Settings>;
    if !IsDefined(this.bus) || !this.bus.IsAttached() || !IsDefined(this.bus.GetAIComponent()) { return; };
    settings = Settings.GetInstance(this.bus.GetGame());
    if !IsDefined(settings) { return; };
    command = new AIVehicleDriveToPointCommand();
    command.secureTimeOut = settings.secureTimeOut;
    command.useTraffic = settings.useTraffic;
    command.speedInTraffic = settings.speedInTraffic;
    command.forceGreenLights = settings.forceGreenLights;
    command.trafficTryNeighborsForStart = settings.trafficTryNeighborsForStart;
    command.trafficTryNeighborsForEnd = settings.trafficTryNeighborsForEnd;
    command.targetPosition = Vector4.Vector4To3(this.target);
    command.minimumDistanceToTarget = 8.00;
    command.needDriver = false;
    command.driveDownTheRoadIndefinitely = false;
    // SendCommand is the path used by Delamain while V is mounted as a
    // passenger. QueueEvent + SetInitCmd is suitable for an empty traffic
    // vehicle, but PassengerEvents can cancel that initialization on 2.3+.
    this.bus.GetAIComponent().SendCommand(command);
    if IsDefined(this.controller) { this.controller.SetActiveRouteCommand(command); };
  }
}

// Direct traffic command supplied by Auto Drive Enhanced. It controls the bus
// only: V remains an ordinary passenger and its AutoDrive UI is never used.
public class NCTCServiceBusController extends IScriptable {
  private let bus: wref<VehicleObject>;
  private let playerAboardSignal: Bool;
  private let activeRouteCommand: ref<AIVehicleDriveToPointCommand>;

  public func Bind(bus: ref<VehicleObject>) -> Bool {
    if !IsDefined(bus) || !IsDefined(bus.GetAIComponent()) { return false; };
    this.bus = bus;
    this.bus.GetVehiclePS().SetIsPlayerVehicle(false);
    return true;
  }

  public func IsReady() -> Bool { return IsDefined(this.bus) && this.bus.IsAttached(); }

  public func GetWorldPosition() -> Vector4 {
    return this.IsReady() ? this.bus.GetWorldPosition() : new Vector4(0.00, 0.00, 0.00, 0.00);
  }

  public func GetCurrentSpeed() -> Float {
    return this.IsReady() ? this.bus.GetCurrentSpeed() : -1.00;
  }

  public func IsNear(position: Vector4, radius: Float) -> Bool {
    return this.IsReady() && Vector4.Distance(this.bus.GetWorldPosition(), position) <= radius;
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

  public func IsPlayerSeated() -> Bool {
    return this.IsReady()
      && Equals(GameInstance.GetQuestsSystem(this.bus.GetGame()).GetFact(n"nctc_player_seated_in_service_bus"), 1);
  }

  public func DistanceToPlayer() -> Float {
    let player: ref<PlayerPuppet>;
    if !this.IsReady() { return 0.00; };
    player = GetPlayer(this.bus.GetGame());
    return IsDefined(player) ? Vector4.Distance(player.GetWorldPosition(), this.bus.GetWorldPosition()) : 0.00;
  }

  public func DriveToTraffic(target: Vector4, minimumDistance: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    if !this.IsReady() { return false; };
    // An empty dynamic bus needs ADE's driver-state bootstrap. Never send its
    // NoDriver/DriverReady pair while V is mounted: it can interrupt the rear
    // passenger workspot and cancel the route command during PassengerEvents.
    if !this.IsPlayerAboard() {
      this.bus.WorkaroundForAutoDriveDontStart_ADE();
    };
    callback = new NCTCDeferredDriveCommand();
    this.activeRouteCommand = null;
    callback.Configure(this.bus, this, target);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.25, false);
    return true;
  }

  public func DriveWithEnhancedAutoDrive(target: Vector4) -> Bool {
    let component: ref<AutoDriveComponent>;
    let settings: ref<Settings>;
    if !this.IsReady() || !this.IsPlayerSeated() || Vector4.IsXYZZero(target) { return false; };
    component = this.bus.GetAutoDriveComponent_ADE();
    settings = Settings.GetInstance(this.bus.GetGame());
    if !IsDefined(component) || !IsDefined(settings) { return false; };
    this.activeRouteCommand = null;
    return component.StartAutoDriveToNCTC(target, Equals(settings.drivingAI, DrivingAIType.ModdedTraffic));
  }

  public func SetActiveRouteCommand(command: ref<AIVehicleDriveToPointCommand>) -> Void {
    this.activeRouteCommand = command;
  }

  public func IsRouteCommandSuccessful() -> Bool {
    return IsDefined(this.activeRouteCommand) && Equals(this.activeRouteCommand.state, AICommandState.Success);
  }

  // Telemetry only. The command state is exposed so the dev runtime can prove
  // whether ADE completes, replaces, or leaves our submitted command active.
  public func GetRouteCommandStatusCode() -> Int32 {
    if !IsDefined(this.activeRouteCommand) { return 0; };
    if Equals(this.activeRouteCommand.state, AICommandState.Success) { return 2; };
    if Equals(this.activeRouteCommand.state, AICommandState.Failure)
      || Equals(this.activeRouteCommand.state, AICommandState.Cancelled)
      || Equals(this.activeRouteCommand.state, AICommandState.Interrupted) { return 3; };
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
    let component: ref<AutoDriveComponent>;
    if !this.IsReady() { return; };
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    component = this.bus.GetAutoDriveComponent_ADE();
    if IsDefined(component) && component.IsAutoDriving() { component.CancelAutoDrive(true); };
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
    return this.DriveToTraffic(target, 8.00);
  }
}

public class NCTCServiceProfiles {
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

  public static func TryGetNextStop(game: GameInstance, line: String, currentStopId: Int32, out nextStopId: Int32, out nextStop: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let requestedLine: Int32 = StringToInt(line, -1);
    let count: Int32;
    let index: Int32 = 0;
    let stopLine: Int32;
    let stopId: Int32;
    let stopSequence: Int32;
    let currentSequence: Int32 = -1;
    let nextSequence: Int32 = 2147483647;
    let firstSequence: Int32 = 2147483647;
    let firstId: Int32 = 0;
    let firstPosition: Vector4;
    let prefix: String;
    if !IsDefined(quests) || requestedLine < 1 || !Equals(quests.GetFact(n"nctc_external_network_ready"), 1) { return false; };
    count = quests.GetFact(n"nctc_external_network_stop_count");
    // IDs are persistent capture keys and are deliberately unrelated to route
    // order. Resolve the current stop's explicit sequence first.
    while index < count {
      prefix = "nctc_external_stop_" + ToString(index) + "_";
      stopLine = quests.GetFact(StringToName(prefix + "line"));
      stopId = quests.GetFact(StringToName(prefix + "id"));
      if Equals(stopLine, requestedLine) && Equals(stopId, currentStopId) {
        currentSequence = quests.GetFact(StringToName(prefix + "sequence"));
        break;
      };
      index += 1;
    };
    if currentSequence < 0 { return false; };

    index = 0;
    while index < count {
      prefix = "nctc_external_stop_" + ToString(index) + "_";
      stopLine = quests.GetFact(StringToName(prefix + "line"));
      if Equals(stopLine, requestedLine) {
        stopId = quests.GetFact(StringToName(prefix + "id"));
        stopSequence = quests.GetFact(StringToName(prefix + "sequence"));
        if stopSequence < firstSequence {
          firstSequence = stopSequence;
          firstId = stopId;
          firstPosition = NCTCServiceProfiles.ReadVector(quests, prefix);
        };
        if stopSequence > currentSequence && stopSequence < nextSequence {
          nextSequence = stopSequence;
          nextStopId = stopId;
          nextStop = NCTCServiceProfiles.ReadVector(quests, prefix);
        };
      };
      index += 1;
    };
    if nextSequence < 2147483647 { return nextStopId > 0; };
    if firstId > 0 {
      nextStopId = firstId;
      nextStop = firstPosition;
      return true;
    };
    return false;
  }

  private static func ReadVector(quests: ref<QuestsSystem>, prefix: String) -> Vector4 {
    return new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "x"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "y"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "z"))) / 1000.00, 1.00);
  }
}

public class NCTCServiceDispatchCallback extends DelayCallback {
  private let system: wref<NCTCTransitSystem>;
  private let token: Int32;
  public func Configure(system: ref<NCTCTransitSystem>, token: Int32) -> Void {
    this.system = system;
    this.token = token;
  }
  public func Call() -> Void {
    if IsDefined(this.system) { this.system.UpdateRequestedServiceForToken(this.token); };
  }
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
  private let surveyYaw: Float;
  private let approachCommandSent: Bool;
  private let routeStarted: Bool;
  private let dwellPolls: Int32;
  private let boardingDoorWasOpen: Bool;
  private let routeWaypoint: NewMappinID;
  private let departureRequested: Bool;
  private let legPolls: Int32;
  private let telemetryPolls: Int32;
  private let adeRouteLeg: Bool;
  private let adeArrivalSignal: Bool;
  // Only the most recently scheduled loop callback may mutate route state.
  // This prevents a delayed retry from an older leg replacing a newer target.
  private let dispatchToken: Int32;

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
    let targetPosition: Vector4 = this.hasSurveyProfile ? this.surveyBerth : this.requestedStop;
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_dev_loop_code", code);
    quests.SetFact(n"nctc_dev_loop_line", StringToInt(this.requestedLine, -1));
    quests.SetFact(n"nctc_dev_loop_stop_id", this.requestedStopId);
    quests.SetFact(n"nctc_dev_loop_next_stop_id", nextStopId);
    quests.SetFact(n"nctc_dev_loop_target_x_mm", Cast<Int32>(targetPosition.X * 1000.00));
    quests.SetFact(n"nctc_dev_loop_target_y_mm", Cast<Int32>(targetPosition.Y * 1000.00));
    quests.SetFact(n"nctc_dev_loop_target_z_mm", Cast<Int32>(targetPosition.Z * 1000.00));
    if IsDefined(this.controller) && this.controller.IsReady() {
      busPosition = this.controller.GetWorldPosition();
      quests.SetFact(n"nctc_dev_loop_bus_x_mm", Cast<Int32>(busPosition.X * 1000.00));
      quests.SetFact(n"nctc_dev_loop_bus_y_mm", Cast<Int32>(busPosition.Y * 1000.00));
      quests.SetFact(n"nctc_dev_loop_bus_z_mm", Cast<Int32>(busPosition.Z * 1000.00));
      quests.SetFact(n"nctc_dev_loop_target_distance_mm", Cast<Int32>(Vector4.Distance(busPosition, targetPosition) * 1000.00));
    };
    quests.SetFact(n"nctc_dev_loop_id", quests.GetFact(n"nctc_dev_loop_id") + 1);
  }

  private func PublishRouteCommandTelemetry() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_dev_command_state", this.controller.GetRouteCommandStatusCode());
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

  public func NotifyADEArrival(entityID: EntityID) -> Void {
    if this.IsActiveServiceBus(entityID) {
      this.adeArrivalSignal = true;
    };
  }

  private func ConsumeADEArrivalSignal() -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_ade_destination_reached"), 1) || !this.controller.IsPlayerAboard() {
      return false;
    };
    quests.SetFact(n"nctc_ade_destination_reached", 0);
    return true;
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
    this.requestedLine = line;
    this.requestedStopId = stopId;
    this.serviceStopId = stopId;
    this.requestedStop = stop;
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
    this.legPolls = 0;
    this.adeRouteLeg = false;
    this.adeArrivalSignal = false;
    GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(n"nctc_ade_destination_reached", 0);
    GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(n"nctc_passenger_departure_requested", 0);
    this.hasSurveyProfile = NCTCServiceProfiles.TryGet(this.GetGameInstance(), line, stopId, this.surveySpawn, this.surveyApproach, this.surveyBerth, this.surveyYaw);
    // Development-only diagnostic bridge. CET writes this to nctc_survey.log;
    // it never creates a player-facing notification and is absent from public builds.
    quests = GameInstance.GetQuestsSystem(this.GetGameInstance());
    player = GetPlayer(this.GetGameInstance());
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
    this.legPolls = 0;
    this.adeRouteLeg = false;
    this.adeArrivalSignal = false;
    GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(n"nctc_ade_destination_reached", 0);
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
    this.dispatchToken += 1;
    callback.Configure(this, this.dispatchToken);
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, delay, false);
  }

  public func UpdateRequestedServiceForToken(token: Int32) -> Void {
    if NotEquals(token, this.dispatchToken) { return; };
    this.UpdateRequestedService();
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
      // The called stop has now been served. Future player stop requests will
      // set serviceStopId again; until then the bus follows its route without
      // opening its doors at intermediate points.
      this.serviceStopId = 0;
      if !this.AdvanceToNextStop() {
        this.PublishLoopDiagnostic(34, 0);
        this.ScheduleDispatch(1.00);
        return;
      };
      this.arrived = false;
      this.dwellPolls = 0;
      this.legPolls = 0;
      this.adeRouteLeg = this.controller.IsPlayerSeated();
      this.adeArrivalSignal = false;
      this.driveCommandSent = this.adeRouteLeg
        ? this.controller.DriveWithEnhancedAutoDrive(this.surveyBerth)
        : this.controller.DriveToTraffic(this.surveyBerth, 8.00);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 32 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.25);
      return;
    };

    if !this.driveCommandSent {
      this.driveCommandSent = this.controller.DriveToTraffic(this.hasSurveyProfile ? this.surveyBerth : this.requestedStop, 8.00);
      this.legPolls = 0;
      this.telemetryPolls = 0;
      this.adeRouteLeg = false;
      this.adeArrivalSignal = false;
      this.PublishLoopDiagnostic(29, this.requestedStopId);
      this.ScheduleDispatch(0.25);
      return;
    };
    this.legPolls += 1;
    // Every five seconds, log the exact state of the command object NCTC
    // submitted to ADE. This is diagnostic-only and lets us distinguish a
    // genuine ADE completion from a vehicle that merely stopped in traffic.
    this.telemetryPolls += 1;
    if this.telemetryPolls >= 10 {
      this.telemetryPolls = 0;
      this.PublishRouteCommandTelemetry();
    };
    // Passenger legs use ADE's own destination callback rather than NCTC's
    // positional hand-off. The inbound, empty-bus leg remains traffic AI and
    // therefore continues to use the baseline berth envelope below.
    if this.adeRouteLeg {
      if this.adeArrivalSignal || this.ConsumeADEArrivalSignal() {
        this.adeArrivalSignal = false;
        if !this.AdvanceToNextStop() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        this.legPolls = 0;
        this.adeRouteLeg = this.controller.IsPlayerSeated();
        this.driveCommandSent = this.adeRouteLeg
          ? this.controller.DriveWithEnhancedAutoDrive(this.surveyBerth)
          : this.controller.DriveToTraffic(this.surveyBerth, 8.00);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 31 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.ScheduleDispatch(0.50);
      return;
    };
    // Baseline service hand-off. ADE's direct traffic command does not expose
    // a terminal Success state to NCTC, so the authored berth envelope is the
    // contract for this prototype: 8m native stopping allowance plus 10m
    // hand-off margin.
    if this.controller.IsNear(this.hasSurveyProfile ? this.surveyBerth : this.requestedStop, 18.00) {
      if Equals(this.requestedStopId, this.serviceStopId) {
        this.controller.ArriveAtStop();
        this.arrived = true;
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
      // so the bus continues without doors or a dwell state.
      if !this.AdvanceToNextStop() {
        this.PublishLoopDiagnostic(34, 0);
        this.ScheduleDispatch(1.00);
        return;
      };
      this.legPolls = 0;
      this.driveCommandSent = this.controller.DriveToTraffic(this.surveyBerth, 8.00);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 31 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.25);
      return;
    };
    if this.controller.IsRouteCommandFailed() {
      this.PublishLoopDiagnostic(35, this.requestedStopId);
      // Mounting can cancel the command once while PassengerEvents settles.
      // Retry the same berth on the next tick; DriveToTraffic deliberately
      // avoids the NoDriver reset whenever V is already aboard.
      this.driveCommandSent = false;
      this.ScheduleDispatch(0.50);
      return;
    };
    this.ScheduleDispatch(0.50);
  }

  private func AdvanceToNextStop() -> Bool {
    let nextStopId: Int32;
    let nextStop: Vector4;
    let nextSpawn: Vector4;
    let nextApproach: Vector4;
    let nextBerth: Vector4;
    let nextYaw: Float;
    if !NCTCServiceProfiles.TryGetNextStop(this.GetGameInstance(), this.requestedLine, this.requestedStopId, nextStopId, nextStop) {
      this.PublishLoopDiagnostic(4, 0);
      return false;
    };
    if !NCTCServiceProfiles.TryGet(this.GetGameInstance(), this.requestedLine, nextStopId, nextSpawn, nextApproach, nextBerth, nextYaw) {
      this.PublishLoopDiagnostic(5, nextStopId);
      return false;
    };
    this.requestedStopId = nextStopId;
    this.requestedStop = nextStop;
    this.surveySpawn = nextSpawn;
    this.surveyApproach = nextApproach;
    this.surveyBerth = nextBerth;
    this.surveyYaw = nextYaw;
    this.hasSurveyProfile = true;
    this.arrived = false;
    this.driveCommandSent = false;
    this.approachCommandSent = false;
    this.routeStarted = true;
    this.dwellPolls = 0;
    this.boardingDoorWasOpen = false;
    this.legPolls = 0;
    this.PublishRouteDisplay(nextStopId);
    this.PublishLoopDiagnostic(6, nextStopId);
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
    this.hasSurveyProfile = NCTCServiceProfiles.TryGet(this.GetGameInstance(), this.requestedLine, this.requestedStopId, this.surveySpawn, this.surveyApproach, this.surveyBerth, this.surveyYaw);
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
