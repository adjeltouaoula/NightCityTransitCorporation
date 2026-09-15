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
public func NCTCIsSeatChoiceVisible() -> Bool {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  return IsDefined(quests) && Equals(quests.GetFact(n"nctc_seat_choice_visible"), 1);
}

@addMethod(PlayerPuppet)
public func NCTCBuildStopRequestChoice() -> ListChoiceData {
  let choice: ListChoiceData;
  let choiceType: ChoiceTypeWrapper;

  ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Selected);
  choice.localizedName = "Demander le prochain arrêt";
  // It is a normal selectable Interaction UI choice, like a seat or a line at
  // a stop. ChoiceApply/F activates it; the configured NCTC key remains only
  // as the existing direct shortcut.
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

// Keep the one-choice request hub in the blackboard while no seat hub owns the
// Interaction UI. r389c/r389d only injected this hub into OnDialogsData's local
// copy, so the UI had no persistent data source and visibly flashed as other
// Interaction UI callbacks refreshed. The blackboard now owns the standalone
// hub exactly like NCTC's existing line-choice UI does.
@addMethod(PlayerPuppet)
public func NCTCSyncStandaloneStopRequestHub() -> Void {
  let defs: ref<UIInteractionsDef> = GetAllBlackboardDefs().UIInteractions;
  let blackboard: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGame()).Get(defs);
  let data: DialogChoiceHubs;
  let cleaned: array<ListChoiceHubData>;
  let hub: ListChoiceHubData;
  let i: Int32 = 0;
  let activeHubId: Int32;
  let hasStandalone: Bool = false;
  let changed: Bool = false;
  let shouldPersist: Bool;

  if !IsDefined(blackboard) { return; };

  shouldPersist = this.NCTCShouldShowStopRequestChoice() && !this.NCTCIsSeatChoiceVisible();
  data = FromVariant<DialogChoiceHubs>(blackboard.GetVariant(defs.DialogChoiceHubs));

  while i < ArraySize(data.choiceHubs) {
    hub = data.choiceHubs[i];
    if Equals(hub.id, 77903) {
      if shouldPersist && !hasStandalone {
        ArrayPush(cleaned, hub);
        hasStandalone = true;
      } else {
        changed = true;
      };
    } else {
      ArrayPush(cleaned, hub);
    };
    i += 1;
  };

  if shouldPersist && !hasStandalone {
    ArrayPush(cleaned, this.NCTCBuildStandaloneStopRequestHub());
    changed = true;
  };

  if changed {
    data.choiceHubs = cleaned;
    blackboard.SetVariant(defs.DialogChoiceHubs, ToVariant(data), true);
  };

  activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);
  if shouldPersist {
    if Equals(activeHubId, 0) || Equals(activeHubId, -1) || Equals(activeHubId, 77901) || Equals(activeHubId, 77903) {
      if !Equals(activeHubId, 77903) {
        blackboard.SetInt(defs.ActiveChoiceHubID, 77903, true);
      };
      blackboard.SetInt(defs.SelectedIndex, 0, true);
    };
  } else {
    if Equals(activeHubId, 77903) {
      if this.NCTCIsSeatChoiceVisible() && this.NCTCShouldShowStopRequestChoice() {
        blackboard.SetInt(defs.ActiveChoiceHubID, 77901, true);
      } else {
        blackboard.SetInt(defs.ActiveChoiceHubID, 0, true);
      };
    };
  };
}

@addMethod(PlayerPuppet)
public func NCTCRefreshStopRequestChoice() -> Void {
  this.nctcStopRequestChoiceVisible = this.NCTCShouldShowStopRequestChoice();
  // This is safe to call every poll: NCTCSyncStandaloneStopRequestHub writes
  // only when the persisted UI state is actually different, so there is no
  // show/hide pulse and therefore no flicker.
  this.NCTCSyncStandaloneStopRequestHub();
}

// Merge the stop-request choice into the existing rear-seat interaction hub
// (77901). If no seat hub is offered (notably while V is seated), the
// standalone hub persisted above is used instead.
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
          // The passenger module's selection index intentionally treats this
          // as the final item after the available seats.
          ArrayPush(hub.choices, player.NCTCBuildStopRequestChoice());
        };
      };
      data.choiceHubs[i] = hub;
    };
    i += 1;
  };

  blackboard = GameInstance.GetBlackboardSystem(player.GetGame()).Get(defs);
  if shouldShowRequest && seatHubFound && IsDefined(blackboard) {
    activeHubId = blackboard.GetInt(defs.ActiveChoiceHubID);
    if Equals(activeHubId, 0) || Equals(activeHubId, -1) || Equals(activeHubId, 77903) {
      blackboard.SetInt(defs.ActiveChoiceHubID, 77901, true);
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

  // Keep the existing Mod Settings/Input Loader key as a shortcut, while the
  // visible interaction itself is selected with arrows + ChoiceApply/F.
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
