module NCTC

// Native stop-request input + HUD. The key binding remains owned by
// Input Loader / Mod Settings through NCTC_RequestNextStop.
//
// Important: patch annotations are used only on the base-game PlayerPuppet
// class. NCTCTransitSystem is a mod-defined class, so it must never be the
// target of @addField/@addMethod/@wrapMethod annotations.

public class NCTCStopRequestHintTick extends DelayCallback {
  private let player: wref<PlayerPuppet>;

  public func Configure(player: ref<PlayerPuppet>) -> ref<NCTCStopRequestHintTick> {
    this.player = player;
    return this;
  }

  public func Call() -> Void {
    let next: ref<NCTCStopRequestHintTick>;
    if !IsDefined(this.player) { return; };

    this.player.NCTCRefreshStopRequestHint();

    next = new NCTCStopRequestHintTick();
    next.Configure(this.player);
    GameInstance.GetDelaySystem(this.player.GetGame()).DelayCallback(next, 0.25, false);
  }
}

@addField(PlayerPuppet)
private let nctcStopRequestHintVisible: Bool;

@addField(PlayerPuppet)
private let nctcStopRequestHintPollStarted: Bool;

@addMethod(PlayerPuppet)
private func NCTCShouldShowStopRequestHint() -> Bool {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  if !IsDefined(quests) { return false; };
  if !Equals(quests.GetFact(n"nctc_player_in_service_bus"), 1) { return false; };
  if Equals(quests.GetFact(n"nctc_display_stop_requested"), 1) { return false; };
  return true;
}

@addMethod(PlayerPuppet)
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
  GameInstance.GetUISystem(this.GetGame()).QueueEvent(evt);
  this.nctcStopRequestHintVisible = true;
}

@addMethod(PlayerPuppet)
private func NCTCHideStopRequestHint() -> Void {
  let evt: ref<DeleteInputHintBySourceEvent>;
  if !this.nctcStopRequestHintVisible { return; };

  evt = new DeleteInputHintBySourceEvent();
  evt.source = n"NCTCStopRequest";
  evt.targetHintContainer = n"GameplayInputHelper";
  GameInstance.GetUISystem(this.GetGame()).QueueEvent(evt);
  this.nctcStopRequestHintVisible = false;
}

@addMethod(PlayerPuppet)
public func NCTCRefreshStopRequestHint() -> Void {
  if this.NCTCShouldShowStopRequestHint() {
    this.NCTCShowStopRequestHint();
  } else {
    this.NCTCHideStopRequestHint();
  };
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let tick: ref<NCTCStopRequestHintTick>;

  if !this.nctcStopRequestHintPollStarted {
    this.nctcStopRequestHintPollStarted = true;
    this.RegisterInputListener(this, n"NCTC_RequestNextStop");
    tick = new NCTCStopRequestHintTick();
    tick.Configure(this);
    GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(tick, 0.25, false);
  };

  return result;
}

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

  consumer.Consume();
  transit = NCTCTransitSystem.Get(this.GetGame());
  if IsDefined(transit) {
    transit.RequestNextStop();
  };
  this.NCTCRefreshStopRequestHint();
  return result;
}
