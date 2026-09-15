module NCTC

// Native stop-request input + HUD. The key itself stays owned by Input Loader /
// Mod Settings through NCTC_RequestNextStop; this file only reacts to that
// native action and publishes the game's normal GameplayInputHelper hint.

@addField(NCTCTransitSystem)
private let nctcStopRequestHintVisible: Bool;

@addMethod(NCTCTransitSystem)
private func NCTCShouldShowStopRequestHint() -> Bool {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
  if !IsDefined(quests) { return false; };
  if !Equals(quests.GetFact(n"nctc_player_in_service_bus"), 1) { return false; };
  if Equals(quests.GetFact(n"nctc_display_stop_requested"), 1) { return false; };
  // At the boarding/alighting dwell GetApproachingLine() is empty because the
  // bus is already at a stop. Only show the request prompt while travelling
  // toward an actual next stop.
  return NotEquals(this.GetApproachingLine(), "");
}

@addMethod(NCTCTransitSystem)
private func NCTCShowStopRequestHint() -> Void {
  let data: InputHintData;
  let evt: ref<UpdateInputHintEvent>;
  if this.nctcStopRequestHintVisible { return; };

  data.action = n"NCTC_RequestNextStop";
  data.source = n"NCTCStopRequest";
  data.localizedLabel = "Demander le prochain arrêt";
  data.enableHoldAnimation = false;
  data.sortingPriority = 1;

  evt = new UpdateInputHintEvent();
  evt.data = data;
  evt.show = true;
  evt.targetHintContainer = n"GameplayInputHelper";
  GameInstance.GetUISystem(this.GetGameInstance()).QueueEvent(evt);
  this.nctcStopRequestHintVisible = true;
}

@addMethod(NCTCTransitSystem)
private func NCTCHideStopRequestHint() -> Void {
  let evt: ref<DeleteInputHintBySourceEvent>;
  if !this.nctcStopRequestHintVisible { return; };

  evt = new DeleteInputHintBySourceEvent();
  evt.source = n"NCTCStopRequest";
  evt.targetHintContainer = n"GameplayInputHelper";
  GameInstance.GetUISystem(this.GetGameInstance()).QueueEvent(evt);
  this.nctcStopRequestHintVisible = false;
}

@addMethod(NCTCTransitSystem)
private func NCTCRefreshStopRequestHint() -> Void {
  if this.NCTCShouldShowStopRequestHint() {
    this.NCTCShowStopRequestHint();
  } else {
    this.NCTCHideStopRequestHint();
  };
}

@wrapMethod(NCTCTransitSystem)
public func SetPlayerAboard(value: Bool) -> Void {
  wrappedMethod(value);
  this.NCTCRefreshStopRequestHint();
}

@wrapMethod(NCTCTransitSystem)
public func RequestNextStop() -> Bool {
  let accepted: Bool = wrappedMethod();
  this.NCTCRefreshStopRequestHint();
  return accepted;
}

@wrapMethod(NCTCTransitSystem)
public func UpdateRequestedService() -> Void {
  wrappedMethod();
  this.NCTCRefreshStopRequestHint();
}

@wrapMethod(NCTCTransitSystem)
public func DespawnServiceBus() -> Bool {
  let result: Bool = wrappedMethod();
  this.NCTCHideStopRequestHint();
  return result;
}

// The action itself is native Input Loader input. No CET registerInput/Observe
// bridge participates in the stop-request feature.
@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  let result: Bool = wrappedMethod(action, consumer);
  let quests: ref<QuestsSystem>;
  let transit: ref<NCTCTransitSystem>;

  if !ListenerAction.IsAction(action, n"NCTC_RequestNextStop") || !ListenerAction.IsButtonJustPressed(action) {
    return result;
  };

  quests = GameInstance.GetQuestsSystem(this.GetGame());
  if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_player_in_service_bus"), 1) {
    return result;
  };

  transit = NCTCTransitSystem.Get(this.GetGame());
  if !IsDefined(transit) { return result; };

  consumer.Consume();
  transit.RequestNextStop();
  return result;
}
