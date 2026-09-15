module NCTC

// Native stop-request input + Interaction UI prompt. The key binding remains
// owned by Input Loader / Mod Settings through NCTC_RequestNextStop.

public class NCTCStopRequestChoiceTick extends DelayCallback {
  private let player: wref<PlayerPuppet>;

  public func Configure(player: ref<PlayerPuppet>) -> ref<NCTCStopRequestChoiceTick> {
    this.player = player;
    return this;
  }

  public func Call() -> Void {
    let next: ref<NCTCStopRequestChoiceTick>;
    if !IsDefined(this.player) { return; };

    this.player.NCTCRefreshStopRequestChoice();

    next = new NCTCStopRequestChoiceTick();
    next.Configure(this.player);
    GameInstance.GetDelaySystem(this.player.GetGame()).DelayCallback(next, 0.25, false);
  }
}

@addField(PlayerPuppet)
private let nctcStopRequestChoiceVisible: Bool;

@addField(PlayerPuppet)
private let nctcStopRequestChoicePollStarted: Bool;

@addMethod(PlayerPuppet)
public func NCTCShouldShowStopRequestChoice() -> Bool {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  if !IsDefined(quests) { return false; };
  if !Equals(quests.GetFact(n"nctc_player_in_service_bus"), 1) { return false; };
  if Equals(quests.GetFact(n"nctc_display_stop_requested"), 1) { return false; };
  return true;
}

@addMethod(PlayerPuppet)
public func NCTCBuildStopRequestChoiceHub() -> ListChoiceHubData {
  let hub: ListChoiceHubData;
  let choice: ListChoiceData;
  let choiceType: ChoiceTypeWrapper;

  hub.id = 77903;
  hub.title = "NIGHT CITY TRANSIT CORPORATION";
  hub.activityState = EVisualizerActivityState.Active;

  ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Selected);
  choice.localizedName = "Demander le prochain arrêt";
  choice.inputActionName = n"NCTC_RequestNextStop";
  choice.type = choiceType;
  ArrayPush(hub.choices, choice);

  return hub;
}

@addMethod(PlayerPuppet)
public func NCTCRefreshStopRequestChoice() -> Void {
  let blackboard = GameInstance.GetBlackboardSystem(this.GetGame()).Get(GetAllBlackboardDefs().UIInteractions);
  let defs = GetAllBlackboardDefs().UIInteractions;
  let activeHubId: Int32;
  let shouldShow: Bool;
  let wasVisible: Bool;

  if !IsDefined(blackboard) { return; };

  shouldShow = this.NCTCShouldShowStopRequestChoice();
  wasVisible = this.nctcStopRequestChoiceVisible;
  activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);

  if shouldShow {
    this.nctcStopRequestChoiceVisible = true;

    // Never steal the Interaction UI while another real interaction owns it
    // (for example the existing rear-seat choice hub). As soon as that hub
    // releases the cursor, this prompt takes its place on the next poll.
    if Equals(activeHubId, 0) || Equals(activeHubId, -1) {
      blackboard.SetVariant(defs.DialogChoiceHubs, blackboard.GetVariant(defs.DialogChoiceHubs), true);
      blackboard.SetInt(defs.ActiveChoiceHubID, 77903, true);
    } else {
      if Equals(activeHubId, 77903) && !wasVisible {
        blackboard.SetVariant(defs.DialogChoiceHubs, blackboard.GetVariant(defs.DialogChoiceHubs), true);
      };
    };
    return;
  };

  this.nctcStopRequestChoiceVisible = false;
  if Equals(activeHubId, 77903) {
    blackboard.SetInt(defs.ActiveChoiceHubID, 0, true);
  };
  if wasVisible || Equals(activeHubId, 77903) {
    blackboard.SetVariant(defs.DialogChoiceHubs, blackboard.GetVariant(defs.DialogChoiceHubs), true);
  };
}

// Inject the NCTC prompt into the same native Interaction UI list used by
// ordinary world interactions. The dedicated input is the same configurable
// NCTC_RequestNextStop action exposed in Mod Settings.
@wrapMethod(InteractionUIBase)
protected cb func OnDialogsData(value: Variant) -> Bool {
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  let data: DialogChoiceHubs;
  let i: Int32;

  if !IsDefined(player) || !player.NCTCShouldShowStopRequestChoice() {
    return wrappedMethod(value);
  };

  data = FromVariant<DialogChoiceHubs>(value);
  i = 0;
  while i < ArraySize(data.choiceHubs) {
    if Equals(data.choiceHubs[i].id, 77903) {
      return wrappedMethod(value);
    };
    i += 1;
  };

  ArrayPush(data.choiceHubs, player.NCTCBuildStopRequestChoiceHub());
  return wrappedMethod(ToVariant(data));
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let tick: ref<NCTCStopRequestChoiceTick>;

  if !this.nctcStopRequestChoicePollStarted {
    this.nctcStopRequestChoicePollStarted = true;
    this.RegisterInputListener(this, n"NCTC_RequestNextStop");
    tick = new NCTCStopRequestChoiceTick();
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
  this.NCTCRefreshStopRequestChoice();
  return result;
}
