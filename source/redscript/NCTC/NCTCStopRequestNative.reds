module NCTC

// Stop request is a normal Interaction UI choice. There is no dedicated NCTC
// key binding: arrows select it and vanilla ChoiceApply (F by default) invokes
// it, exactly like seat and line choices.

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
  choice.inputActionName = n"None";
  choice.type = choiceType;
  return choice;
}

// The passenger module owns one stable interior hub (77901) everywhere inside
// the bus. REDscript only appends the request entry to that hub when available;
// it never creates a competing standalone hub.
@wrapMethod(InteractionUIBase)
protected cb func OnDialogsData(value: Variant) -> Bool {
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  let data: DialogChoiceHubs;
  let hub: ListChoiceHubData;
  let i: Int32 = 0;
  let j: Int32;
  let requestChoiceFound: Bool;

  if !IsDefined(player) || !player.NCTCIsAboardServiceBus() {
    return wrappedMethod(value);
  };

  data = FromVariant<DialogChoiceHubs>(value);
  while i < ArraySize(data.choiceHubs) {
    hub = data.choiceHubs[i];
    if Equals(hub.id, 77901) {
      hub.title = "NIGHT CITY TRANSIT CORPORATION";
      if player.NCTCShouldShowStopRequestChoice() {
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
    };
    i += 1;
  };

  return wrappedMethod(ToVariant(data));
}

@wrapMethod(PlayerPuppet)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
  let result: Bool = wrappedMethod(action, consumer);
  let quests: ref<QuestsSystem>;
  let transit: ref<NCTCTransitSystem>;

  if !ListenerAction.IsButtonJustPressed(action) || !Equals(ListenerAction.GetName(action), n"ChoiceApply") {
    return result;
  };

  quests = GameInstance.GetQuestsSystem(this.GetGame());
  if !IsDefined(quests)
    || !Equals(quests.GetFact(n"nctc_player_in_service_bus"), 1)
    || !Equals(quests.GetFact(n"nctc_stop_request_choice_selected"), 1)
    || !this.NCTCShouldShowStopRequestChoice() {
    return result;
  };

  consumer.Consume();
  quests.SetFact(n"nctc_stop_request_choice_selected", 0);
  transit = NCTCTransitSystem.Get(this.GetGame());
  if IsDefined(transit) {
    transit.RequestNextStop();
  };
  return result;
}
