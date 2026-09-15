module NCTC

// Native stop-request input + Interaction UI prompt. The key binding remains
// owned by Input Loader / Mod Settings through NCTC_RequestNextStop.
//
// When the rear-seat hub exists, the stop request is injected into that same
// hub so ChoiceScrollUp/Down can select either a seat or the stop request. When
// V is seated (or no seat choice is available), a one-choice NCTC hub is used.

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
  // It is now a normal selectable Interaction UI choice, like a seat or a
  // line at a stop. The old dedicated U hint must not be rendered here.
  choice.inputActionName = n"None";
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

  // Only republish on a real visibility transition. Rewriting the blackboard
  // every poll was the source of the visible r389c flicker.
  blackboard.SetVariant(defs.DialogChoiceHubs, blackboard.GetVariant(defs.DialogChoiceHubs), true);
}

// Merge the stop-request choice into the existing rear-seat interaction hub
// (77901). If no seat hub is offered (notably while V is seated), expose one
// standalone request choice instead.
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
          if Equals(hub.choices[j].localizedName, "Demander le prochain arrêt") {
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

  blackboard = GameInstance.GetBlackboardSystem(player.GetGame()).Get(defs);
  if shouldShowRequest && seatHubFound {
    if IsDefined(blackboard) {
      activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);
      if Equals(activeHubId, 0) || Equals(activeHubId, -1) || Equals(activeHubId, 77903) {
        blackboard.SetInt(defs.ActiveChoiceHubID, 77901, true);
      };
    };
  } else {
    if shouldShowRequest && !standaloneFound {
      ArrayPush(data.choiceHubs, player.NCTCBuildStandaloneStopRequestHub());
    };
    if shouldShowRequest && IsDefined(blackboard) {
      activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);
      if Equals(activeHubId, 0) || Equals(activeHubId, -1) || Equals(activeHubId, 77901) {
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
  let defs: ref<UIInteractionsDef>;
  let blackboard: ref<IBlackboard>;
  let activeHubId: Int32;
  let transit: ref<NCTCTransitSystem>;
  let name: CName;
  let requestAccepted: Bool = false;

  if !ListenerAction.IsButtonJustPressed(action) { return result; };

  quests = GameInstance.GetQuestsSystem(this.GetGame());
  if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_player_in_service_bus"), 1) {
    return result;
  };

  name = ListenerAction.GetName(action);

  // Keep the existing Mod Settings/Input Loader key as a shortcut, but the
  // visible interaction is now selected with arrows + ChoiceApply.
  if Equals(name, n"NCTC_RequestNextStop") {
    requestAccepted = true;
  } else {
    if Equals(name, n"ChoiceApply") && this.NCTCShouldShowStopRequestChoice() {
      defs = GetAllBlackboardDefs().UIInteractions;
      blackboard = GameInstance.GetBlackboardSystem(this.GetGame()).Get(defs);
      if IsDefined(blackboard) {
        activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);
        requestAccepted = Equals(activeHubId, 77903)
          || (Equals(activeHubId, 77901) && Equals(quests.GetFact(n"nctc_stop_request_choice_selected"), 1));
      };
    };
  };

  if !requestAccepted { return result; };

  consumer.Consume();
  transit = NCTCTransitSystem.Get(this.GetGame());
  if IsDefined(transit) {
    transit.RequestNextStop();
  };
  this.NCTCRefreshStopRequestChoice();
  return result;
}
