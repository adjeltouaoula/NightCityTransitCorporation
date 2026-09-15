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
public func NCTCIsAboardServiceBus() -> Bool {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  return IsDefined(quests) && Equals(quests.GetFact(n"nctc_player_in_service_bus"), 1);
}

@addMethod(PlayerPuppet)
public func NCTCShouldShowStopRequestChoice() -> Bool {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  if !IsDefined(quests) { return false; };
  if !Equals(quests.GetFact(n"nctc_player_in_service_bus"), 1) { return false; };
  if Equals(quests.GetFact(n"nctc_display_stop_requested"), 1) { return false; };
  return true;
}

@addMethod(PlayerPuppet)
public func NCTCBuildStopRequestChoice() -> ListChoiceData {
  let choice: ListChoiceData;
  let choiceType: ChoiceTypeWrapper;

  ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Selected);
  choice.localizedName = "Demander le prochain arrêt";
  choice.inputActionName = n"NCTC_RequestNextStop";
  choice.type = choiceType;
  return choice;
}

@addMethod(PlayerPuppet)
public func NCTCBuildStandaloneStopRequestHub() -> ListChoiceHubData {
  let hub: ListChoiceHubData;
  hub.id = 77903;
  hub.title = "NIGHT CITY TRANSIT CORPORATION";
  hub.activityState = EVisualizerActivityState.Active;
  hub.hubPriority = Cast<Uint8>(1);
  ArrayPush(hub.choices, this.NCTCBuildStopRequestChoice());
  return hub;
}

@addMethod(PlayerPuppet)
public func NCTCRefreshStopRequestChoice() -> Void {
  let defs: ref<UIInteractionsDef> = GetAllBlackboardDefs().UIInteractions;
  let blackboard: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGame()).Get(defs);
  let shouldShow: Bool;
  let wasVisible: Bool;

  if !IsDefined(blackboard) { return; };

  shouldShow = this.NCTCShouldShowStopRequestChoice();
  wasVisible = this.nctcStopRequestChoiceVisible;
  if Equals(shouldShow, wasVisible) { return; };

  this.nctcStopRequestChoiceVisible = shouldShow;
  if !shouldShow && Equals(blackboard.GetInt(defs.ActiveChoiceHubID), 77903) {
    blackboard.SetInt(defs.ActiveChoiceHubID, 0, true);
  };

  // Refresh only when eligibility changes. r389c refreshed whenever the
  // active hub was 0/-1, which repeatedly recreated the prompt and produced
  // the visible blinking reported in-game.
  blackboard.SetVariant(defs.DialogChoiceHubs, blackboard.GetVariant(defs.DialogChoiceHubs), true);
}

// Merge the stop-request choice into the existing rear-seat interaction hub
// (77901) whenever it is present. This gives one NCTC panel with up to three
// choices: left seat, right seat, request next stop. When the player is aboard
// but no seat interaction is currently offered, a standalone NCTC request hub
// is shown instead. The seat system itself remains untouched.
@wrapMethod(InteractionUIBase)
protected cb func OnDialogsData(value: Variant) -> Bool {
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  let defs: ref<UIInteractionsDef> = GetAllBlackboardDefs().UIInteractions;
  let blackboard: ref<IBlackboard>;
  let data: DialogChoiceHubs;
  let hub: ListChoiceHubData;
  let i: Int32 = 0;
  let j: Int32;
  let seatHubFound: Bool = false;
  let standaloneFound: Bool = false;
  let requestChoiceFound: Bool;
  let shouldShowRequest: Bool;
  let activeHubId: Int32;

  if !IsDefined(player) || !player.NCTCIsAboardServiceBus() {
    return wrappedMethod(value);
  };

  shouldShowRequest = player.NCTCShouldShowStopRequestChoice();
  data = FromVariant<DialogChoiceHubs>(value);

  while i < ArraySize(data.choiceHubs) {
    hub = data.choiceHubs[i];
    if Equals(hub.id, 77901) {
      seatHubFound = true;
      hub.title = "NIGHT CITY TRANSIT CORPORATION";

      if shouldShowRequest {
        requestChoiceFound = false;
        j = 0;
        while j < ArraySize(hub.choices) {
          if Equals(hub.choices[j].inputActionName, n"NCTC_RequestNextStop") {
            requestChoiceFound = true;
            break;
          };
          j += 1;
        };
        if !requestChoiceFound {
          ArrayPush(hub.choices, player.NCTCBuildStopRequestChoice());
        };
      };
      data.choiceHubs[i] = hub;
    } else {
      if Equals(hub.id, 77903) {
        standaloneFound = true;
      };
    };
    i += 1;
  };

  if shouldShowRequest && !seatHubFound && !standaloneFound {
    ArrayPush(data.choiceHubs, player.NCTCBuildStandaloneStopRequestHub());
    blackboard = GameInstance.GetBlackboardSystem(player.GetGame()).Get(defs);
    if IsDefined(blackboard) {
      activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);
      if Equals(activeHubId, 0) || Equals(activeHubId, -1) {
        blackboard.SetInt(defs.ActiveChoiceHubID, 77903, true);
      };
    };
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
