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
  hub.hubPriority = Cast<Uint8>(1);

  ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Selected);
  choice.localizedName = "Demander le prochain arrêt";
  choice.inputActionName = n"NCTC_RequestNextStop";
  choice.type = choiceType;
  ArrayPush(hub.choices, choice);

  return hub;
}

@addMethod(PlayerPuppet)
public func NCTCRefreshStopRequestChoice() -> Void {
  let defs: ref<UIInteractionsDef> = GetAllBlackboardDefs().UIInteractions;
  let blackboard: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGame()).Get(defs);
  let activeHubId: Int32;
  let shouldShow: Bool;
  let wasVisible: Bool;

  if !IsDefined(blackboard) { return; };

  shouldShow = this.NCTCShouldShowStopRequestChoice();
  wasVisible = this.nctcStopRequestChoiceVisible;
  activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);

  if shouldShow {
    this.nctcStopRequestChoiceVisible = true;

    // Re-send the existing dialog data only when our prompt first becomes
    // eligible or when no interaction currently owns the list. The REDscript
    // OnDialogsData wrapper below injects the NCTC choice without replacing
    // any vanilla or modded interaction hub.
    if !wasVisible || Equals(activeHubId, 0) || Equals(activeHubId, -1) {
      blackboard.SetVariant(defs.DialogChoiceHubs, blackboard.GetVariant(defs.DialogChoiceHubs), true);
    };
    return;
  };

  this.nctcStopRequestChoiceVisible = false;
  if Equals(activeHubId, 77903) {
    blackboard.SetInt(defs.ActiveChoiceHubID, 0, true);
  };
  if wasVisible {
    blackboard.SetVariant(defs.DialogChoiceHubs, blackboard.GetVariant(defs.DialogChoiceHubs), true);
  };
}

// Inject the NCTC prompt into the same native dialog-choice UI used by the
// existing passenger-seat choices. The dedicated input remains the same
// configurable NCTC_RequestNextStop action exposed in Mod Settings.
@wrapMethod(InteractionUIBase)
protected cb func OnDialogsData(value: Variant) -> Bool {
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  let defs: ref<UIInteractionsDef> = GetAllBlackboardDefs().UIInteractions;
  let blackboard: ref<IBlackboard>;
  let data: DialogChoiceHubs;
  let activeHubId: Int32;
  let activeHubStillExists: Bool = false;
  let hasNCTCHub: Bool = false;
  let i: Int32 = 0;

  if !IsDefined(player) || !player.NCTCShouldShowStopRequestChoice() {
    return wrappedMethod(value);
  };

  data = FromVariant<DialogChoiceHubs>(value);
  blackboard = GameInstance.GetBlackboardSystem(player.GetGame()).Get(defs);
  if IsDefined(blackboard) {
    activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);
  };

  while i < ArraySize(data.choiceHubs) {
    if Equals(data.choiceHubs[i].id, 77903) { hasNCTCHub = true; };
    if Equals(data.choiceHubs[i].id, activeHubId) { activeHubStillExists = true; };
    i += 1;
  };

  if !hasNCTCHub {
    ArrayPush(data.choiceHubs, player.NCTCBuildStopRequestChoiceHub());
  };

  // Respect a real active interaction (notably the rear-seat hub). If its
  // injected hub disappears, its ActiveChoiceHubID can remain stale; in that
  // case hand the list to the NCTC stop-request hub instead of leaving the UI
  // focused on a non-existent choice.
  if IsDefined(blackboard)
    && (Equals(activeHubId, 0) || Equals(activeHubId, -1) || (!activeHubStillExists && !Equals(activeHubId, 77903))) {
    blackboard.SetInt(defs.ActiveChoiceHubID, 77903, true);
  };

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
