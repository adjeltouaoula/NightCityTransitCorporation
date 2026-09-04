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
  // First surveyed passage: L17, Skyline Est -> QG Delamain -> Petrel Street.
  public static func TryGet(game: GameInstance, line: String, stop: Vector4, out spawn: Vector4, out approach: Vector4, out berth: Vector4, out yaw: Float) -> Bool {
    berth = new Vector4(-907.910, -81.144, 7.062, 1.000);
    if !Equals(line, "17") || Vector4.Distance(stop, berth) > 35.00 { return false; };
    spawn = new Vector4(-725.033, -214.182, 7.982, 1.000);
    approach = new Vector4(-858.917, -117.867, 7.063, 1.000);
    yaw = 53.138;
    NCTCServiceProfiles.ApplyImportedSurvey(game, spawn, approach, berth, yaw);
    return true;
  }

  // CET writes values scaled by 1,000 as quest facts. This gives the dev
  // survey a deliberate, save-scoped live import path with no disk access.
  private static func ApplyImportedSurvey(game: GameInstance, out spawn: Vector4, out approach: Vector4, out berth: Vector4, out yaw: Float) -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_survey_imported_passage"), 0) { return; };
    if Equals(quests.GetFact(n"nctc_survey_spawn_valid"), 1) {
      spawn = new Vector4(Cast<Float>(quests.GetFact(n"nctc_survey_spawn_x")) / 1000.00, Cast<Float>(quests.GetFact(n"nctc_survey_spawn_y")) / 1000.00, Cast<Float>(quests.GetFact(n"nctc_survey_spawn_z")) / 1000.00, 1.00);
      yaw = Cast<Float>(quests.GetFact(n"nctc_survey_spawn_yaw")) / 1000.00;
    };
    if Equals(quests.GetFact(n"nctc_survey_approach_valid"), 1) {
      approach = new Vector4(Cast<Float>(quests.GetFact(n"nctc_survey_approach_x")) / 1000.00, Cast<Float>(quests.GetFact(n"nctc_survey_approach_y")) / 1000.00, Cast<Float>(quests.GetFact(n"nctc_survey_approach_z")) / 1000.00, 1.00);
    };
    if Equals(quests.GetFact(n"nctc_survey_berth_valid"), 1) {
      berth = new Vector4(Cast<Float>(quests.GetFact(n"nctc_survey_berth_x")) / 1000.00, Cast<Float>(quests.GetFact(n"nctc_survey_berth_y")) / 1000.00, Cast<Float>(quests.GetFact(n"nctc_survey_berth_z")) / 1000.00, 1.00);
    };
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

  public func RequestService(line: String, stop: Vector4) -> Bool {
    if this.requestPending || EntityID.IsDefined(this.busEntityID) { return false; };
    this.requestedLine = line;
    this.requestedStop = stop;
    this.requestPending = true;
    this.arrived = false;
    this.driveCommandSent = false;
    this.approachCommandSent = false;
    this.hasSurveyProfile = NCTCServiceProfiles.TryGet(this.GetGameInstance(), line, stop, this.surveySpawn, this.surveyApproach, this.surveyBerth, this.surveyYaw);
    this.ScheduleDispatch(0.50);
    return true;
  }

  public func GetApproachingLine() -> String {
    if (this.requestPending || EntityID.IsDefined(this.busEntityID)) && !this.arrived {
      return this.requestedLine;
    };
    return "";
  }

  private func ScheduleDispatch(delay: Float) -> Void {
    let callback: ref<NCTCServiceDispatchCallback> = new NCTCServiceDispatchCallback();
    callback.Configure(this);
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, delay, false);
  }

  // Dynamic entities become available one or more frames after CreateEntity,
  // therefore command dispatch is deferred and retries only while requested.
  public func UpdateRequestedService() -> Void {
    if this.requestPending { this.SpawnRequestedService(); };
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
    this.requestPending = false;
    return EntityID.IsDefined(this.busEntityID);
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
