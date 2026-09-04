module NCTC
import AutoDriveEnhanced.*

// Direct traffic command supplied by Auto Drive Enhanced. It controls the bus
// only: V remains an ordinary passenger and its AutoDrive UI is never used.
public class NCTCServiceBusController extends IScriptable {
  private let bus: wref<VehicleObject>;

  public func Bind(bus: ref<VehicleObject>) -> Bool {
    if !IsDefined(bus) || !IsDefined(bus.GetAIComponent()) { return false; };
    this.bus = bus;
    this.bus.GetVehiclePS().SetIsPlayerVehicle(false);
    return true;
  }

  public func IsReady() -> Bool { return IsDefined(this.bus) && this.bus.IsAttached(); }

  public func IsNear(position: Vector4, radius: Float) -> Bool {
    return this.IsReady() && Vector4.Distance(this.bus.GetWorldPosition(), position) <= radius;
  }

  public func DriveToTraffic(target: Vector4, minimumDistance: Float) -> Bool {
    let command: ref<AIVehicleDriveToPointCommand>;
    let event: ref<AICommandEvent>;
    let settings: ref<Settings>;
    if !this.IsReady() { return false; };
    settings = Settings.GetInstance(this.bus.GetGame());
    if !IsDefined(settings) { return false; };
    command = new AIVehicleDriveToPointCommand();
    command.secureTimeOut = settings.secureTimeOut;
    command.useTraffic = settings.useTraffic;
    command.speedInTraffic = settings.speedInTraffic;
    command.forceGreenLights = settings.forceGreenLights;
    command.trafficTryNeighborsForStart = settings.trafficTryNeighborsForStart;
    command.trafficTryNeighborsForEnd = settings.trafficTryNeighborsForEnd;
    command.targetPosition = Vector4.Vector4To3(target);
    // ADE's ordinary-car stopping distance is too broad for a bus berth.
    command.minimumDistanceToTarget = minimumDistance;
    command.needDriver = false;
    command.driveDownTheRoadIndefinitely = false;
    event = new AICommandEvent();
    event.command = command;
    this.bus.QueueEvent(event);
    return true;
  }

  public func CancelTrafficRoute() -> Void {
    if this.IsReady() {
      this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    };
  }

  public func ArriveAndOpenDoor() -> Void {
    let slot: MountingSlotId;
    if !this.IsReady() { return; };
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    slot.id = n"seat_front_right";
    VehicleComponent.OpenDoor(this.bus, slot);
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
    yaw = Cast<Float>(quests.GetFact(StringToName(prefix + "spawn_yaw"))) / 1000.00;
    return true;
  }

  private static func ReadVector(quests: ref<QuestsSystem>, prefix: String) -> Vector4 {
    return new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "x"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "y"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "z"))) / 1000.00, 1.00);
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

  public static func Get(game: GameInstance) -> ref<NCTCTransitSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<NCTCTransitSystem>()) as NCTCTransitSystem;
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
    this.requestedStop = stop;
    this.requestPending = true;
    this.arrived = false;
    this.driveCommandSent = false;
    this.approachCommandSent = false;
    this.hasSurveyProfile = NCTCServiceProfiles.TryGet(this.GetGameInstance(), line, stopId, this.surveySpawn, this.surveyApproach, this.surveyBerth, this.surveyYaw);
    // Development-only diagnostic bridge. CET writes this to nctc_survey.log;
    // it never creates a player-facing notification and is absent from public builds.
    quests = GameInstance.GetQuestsSystem(this.GetGameInstance());
    player = GetPlayer(this.GetGameInstance());
    if IsDefined(quests) {
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
    if EntityID.IsDefined(this.busEntityID) && IsDefined(entitySystem) { entitySystem.DeleteEntity(this.busEntityID); };
    this.busEntityID = new EntityID();
    this.controller = null;
    this.requestPending = false;
    this.driveCommandSent = false;
    this.approachCommandSent = false;
    this.arrived = false;
    this.hasSurveyProfile = false;
    return hadBus;
  }

  private func ScheduleDispatch(delay: Float) -> Void {
    let callback: ref<NCTCServiceDispatchCallback> = new NCTCServiceDispatchCallback();
    callback.Configure(this);
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, delay, false);
  }

  // Dynamic entities become available one or more frames after CreateEntity,
  // therefore command dispatch is deferred and retries only while requested.
  public func UpdateRequestedService() -> Void {
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
    if !this.driveCommandSent {
      // An approach point is route context, never an ADE destination: using
      // it as one made the bus brake, stop, then restart before the berth.
      this.driveCommandSent = this.controller.DriveToTraffic(this.hasSurveyProfile ? this.surveyBerth : this.requestedStop, 8.00);
      this.ScheduleDispatch(0.25);
      return;
    };
    if !this.arrived && this.controller.IsNear(this.hasSurveyProfile ? this.surveyBerth : this.requestedStop, 4.00) {
      this.controller.ArriveAndOpenDoor();
      this.arrived = true;
      return;
    };
    if !this.arrived { this.ScheduleDispatch(0.50); };
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
