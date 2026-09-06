import NCTC.*

// This is the earliest script-visible vehicle-impact event.  Vanilla turns it
// into Attacks.CarHitPlayer afterwards, so the original vehicle ID is only
// available here.
@wrapMethod(PlayerPuppet)
protected cb func OnCarHitPlayer(evt: ref<OnCarHitPlayer>) -> Bool {
  let transit: ref<NCTCTransitSystem>;

  if !IsDefined(evt) { return wrappedMethod(evt); };
  transit = NCTCTransitSystem.Get(this.GetGame());
  // V is standing inside this exact service bus, not being struck by it.
  // All external impacts and all other vehicles remain untouched vanilla.
  if Equals(GameInstance.GetQuestsSystem(this.GetGame()).GetFact(n"nctc_player_in_service_bus"), 1)
    && IsDefined(transit) && transit.IsActiveServiceBus(evt.carId) {
    return false;
  };

  return wrappedMethod(evt);
}
