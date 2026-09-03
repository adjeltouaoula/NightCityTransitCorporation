module NCTC

// Runtime owner for one requested NCTC service.  Route progression and
// passenger boarding will build on this object; it is intentionally separate
// from map-marker registration.
public class NCTCTransitSystem extends ScriptableSystem {
  private let busEntityID: EntityID;
  private let requestedLine: String;
  private let requestedStop: Vector4;
  private let requestPending: Bool;

  public static func Get(game: GameInstance) -> ref<NCTCTransitSystem> {
    return GameInstance.GetScriptableSystemsContainer(game)
      .Get(NameOf<NCTCTransitSystem>()) as NCTCTransitSystem;
  }

  public func RequestService(line: String, stop: Vector4) -> Bool {
    if this.requestPending || EntityID.IsDefined(this.busEntityID) {
      return false;
    };
    this.requestedLine = line;
    this.requestedStop = stop;
    this.requestPending = true;
    return true;
  }

  public func HasPendingRequest() -> Bool {
    return this.requestPending;
  }

  // The first live request spawns the public bus.  The approach point and
  // traffic command are added in the next step, once the terminal action
  // passes a surveyed stop position here.
  public func SpawnRequestedService() -> Bool {
    let record: ref<Vehicle_Record>;
    let spec: ref<DynamicEntitySpec>;
    let entitySystem: ref<DynamicEntitySystem>;
    let player: ref<PlayerPuppet>;

    if !this.requestPending {
      return false;
    };
    entitySystem = GameInstance.GetDynamicEntitySystem();
    player = GetPlayer(this.GetGameInstance());
    record = TweakDBInterface.GetVehicleRecord(t"Vehicle.nctc_service_mahir_mt28_coach");
    if !IsDefined(entitySystem) || !entitySystem.IsReady() || !IsDefined(player) || !IsDefined(record) {
      return false;
    };

    spec = new DynamicEntitySpec();
    spec.recordID = t"Vehicle.nctc_service_mahir_mt28_coach";
    spec.templatePath = record.EntityTemplatePath();
    spec.appearanceName = record.AppearanceName();
    spec.position = player.GetWorldPosition() + Vector4.Normalize(player.GetWorldForward()) * 100.00;
    spec.orientation = player.GetWorldOrientation();
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
}
