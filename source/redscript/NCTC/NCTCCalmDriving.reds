module NCTC

// The NCTC service bus is public transport, not a generic crowd vehicle.
// Downgrade reaction events to the game's light reaction path so collisions,
// gunfire or nearby chaos cannot switch the active service bus into panic/flee.
// The autonomous traffic command remains active, so ordinary braking, lane
// selection and obstacle routing are still handled by the traffic controller.
@wrapMethod(VehicleObject)
protected cb func OnHandleReactionEvent(evt: ref<HandleReactionEvent>) -> Bool {
  let quests: ref<QuestsSystem>;
  if NCTCServiceProtection.IsActiveServiceBus(this.GetGame(), this) {
    quests = GameInstance.GetQuestsSystem(this.GetGame());
    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_service_calm_reaction_id", quests.GetFact(n"nctc_dev_service_calm_reaction_id") + 1);
    };
    this.ResendHandleReactionEvent();
    return true;
  };
  return wrappedMethod(evt);
}
