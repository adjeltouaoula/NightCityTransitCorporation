module NCTC

// Development-only first physical stop prototype.
//
// The important part of this experiment is not the final art asset: it proves
// that the same external network used by NCTC map markers and service calls can
// also drive a real world entity. The prototype deliberately targets one
// authored roadside stop (line 17, stop id 22) and uses a vanilla data terminal
// as a visible placeholder. Once placement is validated in-game, the template
// can be replaced by the final NCTC stop entity without changing the data path.
public class NCTCPhysicalStopPrototype {
  private static func PrototypeStopId() -> Int32 {
    return 22;
  }

  private static func PrototypeTag() -> CName {
    return n"NCTC.PhysicalStopPrototype";
  }

  private static func ReadStopPosition(game: GameInstance, stopId: Int32, out position: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let count: Int32;
    let index: Int32 = 0;
    let prefix: String;
    let id: Int32;

    if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_external_network_ready"), 1) {
      return false;
    };

    count = quests.GetFact(n"nctc_external_network_stop_count");
    while index < count {
      prefix = "nctc_external_stop_" + ToString(index) + "_";
      id = quests.GetFact(StringToName(prefix + "id"));
      if Equals(id, stopId) {
        position = new Vector4(
          Cast<Float>(quests.GetFact(StringToName(prefix + "x"))) / 1000.00,
          Cast<Float>(quests.GetFact(StringToName(prefix + "y"))) / 1000.00,
          Cast<Float>(quests.GetFact(StringToName(prefix + "z"))) / 1000.00,
          1.00
        );
        return AbsF(position.X) > 1.00 || AbsF(position.Y) > 1.00;
      };
      index += 1;
    };

    return false;
  }

  public static func TrySpawn(game: GameInstance) -> Bool {
    let entities: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let position: Vector4;
    let spec: ref<DynamicEntitySpec>;
    let facing: Vector4;
    let tag: CName = NCTCPhysicalStopPrototype.PrototypeTag();

    if !IsDefined(entities) || !entities.IsReady() {
      return false;
    };

    // Player attachment can happen more than once in a session. Dynamic entity
    // tags give us a stable group key and prevent duplicate props.
    if entities.IsPopulated(tag) {
      return true;
    };

    if !NCTCPhysicalStopPrototype.ReadStopPosition(game, NCTCPhysicalStopPrototype.PrototypeStopId(), position) {
      return false;
    };

    spec = new DynamicEntitySpec();
    spec.templatePath = r"base\gameplay\devices\fast_travel\data_term_1.ent";
    spec.position = position;

    // Stop 22's surveyed berth lies roughly east/north-east of the passenger
    // stop point. Face the temporary terminal toward the road for the first
    // visual test; final per-stop orientation will come from capture geometry.
    facing = new Vector4(5.830, 1.548, 0.000, 0.000);
    spec.orientation = EulerAngles.ToQuat(Vector4.ToRotation(facing));

    spec.persistState = false;
    spec.persistSpawn = false;
    spec.alwaysSpawned = false;
    spec.spawnInView = true;
    spec.active = true;
    spec.tags = [tag];

    entities.CreateEntity(spec);
    return true;
  }
}

public class NCTCPhysicalStopPrototypeCallback extends DelayCallback {
  public let game: GameInstance;
  public let attempt: Int32;

  public func Call() -> Void {
    let next: ref<NCTCPhysicalStopPrototypeCallback>;

    if NCTCPhysicalStopPrototype.TrySpawn(this.game) {
      return;
    };

    // CET publishes nctc_network.json to quest facts just after game attach.
    // Retry for up to one minute so load order does not decide whether the
    // physical stop exists.
    if this.attempt >= 120 {
      return;
    };

    next = new NCTCPhysicalStopPrototypeCallback();
    next.game = this.game;
    next.attempt = this.attempt + 1;
    GameInstance.GetDelaySystem(this.game).DelayCallback(next, 0.50);
  }
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let callback: ref<NCTCPhysicalStopPrototypeCallback> = new NCTCPhysicalStopPrototypeCallback();

  callback.game = this.GetGame();
  callback.attempt = 0;
  GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(callback, 1.00);

  return result;
}
