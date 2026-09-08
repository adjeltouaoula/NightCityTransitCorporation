module NCTC

public abstract class NCTCServiceProtection {
  public static func IsActiveServiceBus(game: GameInstance, object: ref<GameObject>) -> Bool {
    let transit: ref<NCTCTransitSystem>;
    if !IsDefined(object) { return false; };
    transit = NCTCTransitSystem.Get(game);
    return IsDefined(transit) && transit.IsActiveServiceBus(object.GetEntityID());
  }

  public static func IsServiceBusHit(hitEvent: ref<gameHitEvent>) -> Bool {
    let source: ref<GameObject>;
    let instigator: ref<GameObject>;
    let game: GameInstance;
    if !IsDefined(hitEvent) || !IsDefined(hitEvent.attackData) { return false; };
    source = hitEvent.attackData.GetSource();
    instigator = hitEvent.attackData.GetInstigator();
    if IsDefined(source) {
      game = source.GetGame();
    } else {
      if IsDefined(instigator) {
        game = instigator.GetGame();
      } else {
        return false;
      };
    };
    return NCTCServiceProtection.IsActiveServiceBus(game, source)
      || NCTCServiceProtection.IsActiveServiceBus(game, instigator);
  }
}

// Vehicle impacts normally feed DamageSystem's prevention request, which can
// make a passenger inherit police heat from an autonomous vehicle. Suppress
// only requests whose source/instigator is the exact active NCTC service bus.
// Existing heat and every action performed by V remain untouched.
@wrapMethod(DamageSystem)
private final func SendDamageRequestToPreventionSystem(hitEvent: ref<gameHitEvent>) -> Void {
  let quests: ref<QuestsSystem>;
  if NCTCServiceProtection.IsServiceBusHit(hitEvent) {
    quests = GameInstance.GetQuestsSystem(GetGameInstance());
    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_service_crime_suppressed_id", quests.GetFact(n"nctc_dev_service_crime_suppressed_id") + 1);
    };
    return;
  };
  wrappedMethod(hitEvent);
}
