module NCTC

public class NCTCStopPrompt {
  public static func FormatTerminalTitle(lines: array<String>, stops: array<String>) -> String {
    let index: Int32 = 1;
    let title: String;
    if ArraySize(lines) == 1 { return stops[0] + "\nNCTC • LIGNE " + lines[0]; };
    title = stops[0] + "\nTRANSFER: " + lines[0];
    while index < ArraySize(lines) { title += " · " + lines[index]; index += 1; };
    return title;
  }

  public static func IsNearStop(game: GameInstance, out line: String, out stop: Vector4, out stopIndex: Int32, out stopId: Int32) -> Bool {
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let markers: ref<NCTCMapMarkerSystem>;
    if !IsDefined(player) { return false; };
    markers = NCTCMapMarkerSystem.GetInstance(game);
    if !IsDefined(markers) || !markers.GetNearestService(player.GetWorldPosition(), line, stop, stopIndex, stopId) { return false; };
    return Vector4.Distance(player.GetWorldPosition(), stop) <= 6.00;
  }

  public static func FormatTitle(game: GameInstance) -> String {
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(game);
    let lines: array<String>;
    let stops: array<String>;
    let index: Int32 = 1;
    let title: String;
    if !IsDefined(player) || !IsDefined(markers) || !markers.GetNearestStopServices(player.GetWorldPosition(), lines, stops) { return "Attendre le bus"; };
    if ArraySize(lines) == 1 { return "Ligne " + lines[0] + " — " + stops[0]; };
    title = "Correspondance — lignes " + lines[0];
    while index < ArraySize(lines) { title += ", " + lines[index]; index += 1; };
    return title;
  }

  public static func IsNearTravelTerminal(game: GameInstance) -> Bool {
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(game);
    let locKey: String;
    let position: Vector4;
    if !IsDefined(player) || !IsDefined(markers) || !markers.GetNearestTravelAnchor(player.GetWorldPosition(), locKey, position) { return false; };
    return Vector4.Distance(player.GetWorldPosition(), position) <= 6.00;
  }

  private static func StartHubChoice(game: GameInstance, position: Vector4) -> Bool {
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(game);
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let lines: array<String>;
    let stopIds: array<Int32>;
    let stop: Vector4;
    if !IsDefined(markers) || !IsDefined(player) || !markers.GetNearestServiceChoices(position, lines, stopIds, stop) || ArraySize(lines) < 1 { return false; };
    player.m_nctcHubChoiceLines = lines;
    player.m_nctcHubChoiceStopIds = stopIds;
    player.m_nctcHubChoicePosition = stop;
    player.m_nctcHubChoiceIndex = 0;
    player.m_nctcHubChoiceActive = true;
    NCTCStopPrompt.UpdateHubChoiceUI(game);
    return true;
  }

  public static func ClearHubChoice(player: ref<PlayerPuppet>) -> Void {
    if !IsDefined(player) { return; };
    NCTCStopPrompt.HideHubChoiceUI(player.GetGame());
    player.m_nctcHubChoiceActive = false;
    ArrayClear(player.m_nctcHubChoiceLines);
    ArrayClear(player.m_nctcHubChoiceStopIds);
  }

  private static func UpdateHubChoiceUI(game: GameInstance) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let defs: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
    let blackboard: ref<IBlackboard> = GameInstance.GetBlackboardSystem(game).Get(defs.UIInteractions);
    let data: DialogChoiceHubs;
    let hub: ListChoiceHubData;
    let choice: ListChoiceData;
    let choiceType: ChoiceTypeWrapper;
    let index: Int32 = 0;
    if !IsDefined(player) || !player.m_nctcHubChoiceActive { return; };
    hub.id = 77902;
    hub.title = "NCTC — Choisir une ligne";
    hub.activityState = EVisualizerActivityState.Active;
    hub.hubPriority = Cast<Uint8>(1);
    while index < ArraySize(player.m_nctcHubChoiceLines) {
      choice.localizedName = "Attendre le bus " + player.m_nctcHubChoiceLines[index];
      choice.inputActionName = n"None";
      ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Selected);
      choice.type = choiceType;
      ArrayPush(hub.choices, choice);
      index += 1;
    };
    ArrayPush(data.choiceHubs, hub);
    blackboard.SetVariant(defs.UIInteractions.DialogChoiceHubs, ToVariant(data), true);
    blackboard.SetInt(defs.UIInteractions.ActiveChoiceHubID, hub.id, true);
    blackboard.SetInt(defs.UIInteractions.SelectedIndex, player.m_nctcHubChoiceIndex, true);
  }

  private static func HideHubChoiceUI(game: GameInstance) -> Void {
    let defs: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
    let blackboard: ref<IBlackboard> = GameInstance.GetBlackboardSystem(game).Get(defs.UIInteractions);
    let data: DialogChoiceHubs;
    blackboard.SetVariant(defs.UIInteractions.DialogChoiceHubs, ToVariant(data), true);
    blackboard.SetInt(defs.UIInteractions.ActiveChoiceHubID, 0, true);
  }

  public static func SetVisible(game: GameInstance, visible: Bool) -> Void {
    let hub: InteractionChoiceHubData;
    let choice: InteractionChoiceData;
    let choices: array<InteractionChoiceData>;
    let choiceType: ChoiceTypeWrapper;
    let visualizers: VisualizersInfo;
    let defs: ref<AllBlackboardDefinitions>;
    let blackboard: ref<IBlackboard>;
    hub.id = -12017; hub.active = visible; hub.flags = IntEnum<EVisualizerDefinitionFlags>(0);
    hub.title = NCTCStopPrompt.FormatTitle(game);
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(game);
    let lines: array<String>;
    let stopIds: array<Int32>;
    let stop: Vector4;
    if IsDefined(NCTCSettings.Get(game)) && NCTCSettings.Get(game).ShouldRecordTerminalStops() {
      hub.title = "NCTC DEV";
      choice.localizedName = "Enregistrer l arret";
      choice.inputAction = n"UI_Apply";
      ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Blueline);
      choice.type = choiceType;
      ArrayPush(choices, choice);
    } else if IsDefined(GetPlayer(game)) && GetPlayer(game).m_nctcHubChoiceActive {
      hub.active = false;
    } else if IsDefined(markers) && markers.GetNearestServiceChoices(GetPlayer(game).GetWorldPosition(), lines, stopIds, stop) {
      // A single service is immediately callable. A metro transfer retains one
      // parent action so it can coexist with the native metro/fast-travel UI.
      choice.localizedName = ArraySize(lines) == 1 ? "Attendre le bus " + lines[0] : "Attendre un bus";
      choice.inputAction = n"UI_Apply";
      ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Blueline);
      choice.type = choiceType;
      ArrayPush(choices, choice);
    } else {
      choice.localizedName = "Attendre le bus";
      choice.inputAction = n"UI_Apply";
      ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Blueline);
      choice.type = choiceType;
      ArrayPush(choices, choice);
    };
    hub.choices = choices;
    visualizers.activeVisId = hub.id; visualizers.visIds = [hub.id];
    defs = GetAllBlackboardDefs(); blackboard = GameInstance.GetBlackboardSystem(game).Get(defs.UIInteractions);
    blackboard.SetVariant(defs.UIInteractions.InteractionChoiceHub, ToVariant(hub), true);
    blackboard.SetVariant(defs.UIInteractions.VisualizersInfo, ToVariant(visualizers), true);
  }

  public static func NotifyRequest(game: GameInstance, line: String) -> Void {
    let message: SimpleScreenMessage;
    let defs: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
    message.isShown = true; message.duration = 4.00;
    message.message = "NCTC — Ligne " + line + " : bus en approche";
    message.type = SimpleMessageType.DelamainTaxi;
    GameInstance.GetBlackboardSystem(game).Get(defs.UI_Notifications).SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(message), true);
  }

  public static func Refresh(game: GameInstance) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let settings: ref<NCTCSettings> = NCTCSettings.Get(game);
    let line: String; let stop: Vector4; let stopIndex: Int32; let stopId: Int32;
    let nearStop: Bool;
    let visible: Bool;
    let choiceLines: array<String>;
    let choiceStopIds: array<Int32>;
    let choicePosition: Vector4;
    let ordinaryHub: Bool;
    if !IsDefined(player) { return; };
    nearStop = IsDefined(settings) && settings.ShouldRecordTerminalStops() ? NCTCStopPrompt.IsNearTravelTerminal(game) : NCTCStopPrompt.IsNearStop(game, line, stop, stopIndex, stopId);
    if !nearStop { NCTCStopPrompt.ClearHubChoice(player); };
    // Ordinary hubs open straight onto their line choices.  A metro hub keeps
    // a single parent action so vanilla Fast Travel / Metro actions remain
    // usable alongside it; that parent action alone opens the line picker.
    ordinaryHub = false;
    if nearStop && !(IsDefined(settings) && settings.ShouldRecordTerminalStops()) {
      let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(game);
      if IsDefined(markers) && markers.GetNearestServiceChoices(player.GetWorldPosition(), choiceLines, choiceStopIds, choicePosition) {
        ordinaryHub = ArraySize(choiceLines) > 1 && !markers.IsNearMetroAnchor(player.GetWorldPosition());
      };
    };
    if ordinaryHub && !player.m_nctcHubChoiceActive { NCTCStopPrompt.StartHubChoice(game, player.GetWorldPosition()); };
    visible = nearStop && !player.m_nctcHubChoiceActive;
    if visible || !Equals(player.m_nctcPromptVisible, visible) { NCTCStopPrompt.SetVisible(game, visible); };
    player.m_nctcPromptVisible = visible;
  }
}

public class NCTCStopPromptCallback extends DelayCallback {
  public let game: GameInstance;
  public func Call() -> Void {
    let next: ref<NCTCStopPromptCallback> = new NCTCStopPromptCallback();
    NCTCStopPrompt.Refresh(this.game); next.game = this.game;
    GameInstance.GetDelaySystem(this.game).DelayCallback(next, 0.10);
  }
}

public class NCTCStopPromptInputListener {
  public let game: GameInstance;
  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let player: ref<PlayerPuppet>; let settings: ref<NCTCSettings>; let markers: ref<NCTCMapMarkerSystem>; let line: String; let locKey: String; let stop: Vector4; let stopIndex: Int32; let stopId: Int32; let name: CName;
    name = ListenerAction.GetName(action);
    player = GetPlayer(this.game);
    if !IsDefined(player) { return false; };
    if player.m_nctcHubChoiceActive {
      if Equals(name, n"ChoiceScrollUp") && ListenerAction.IsButtonJustPressed(action) {
        player.m_nctcHubChoiceIndex -= 1;
        if player.m_nctcHubChoiceIndex < 0 { player.m_nctcHubChoiceIndex = ArraySize(player.m_nctcHubChoiceLines) - 1; };
        NCTCStopPrompt.UpdateHubChoiceUI(this.game);
        return true;
      };
      if Equals(name, n"ChoiceScrollDown") && ListenerAction.IsButtonJustPressed(action) {
        player.m_nctcHubChoiceIndex += 1;
        if player.m_nctcHubChoiceIndex >= ArraySize(player.m_nctcHubChoiceLines) { player.m_nctcHubChoiceIndex = 0; };
        NCTCStopPrompt.UpdateHubChoiceUI(this.game);
        return true;
      };
      if Equals(name, n"ChoiceApply") && ListenerAction.IsButtonJustPressed(action) {
        let selected: Int32 = player.m_nctcHubChoiceIndex;
        if NCTCTransitSystem.Get(this.game).RequestService(player.m_nctcHubChoiceLines[selected], player.m_nctcHubChoiceStopIds[selected], player.m_nctcHubChoicePosition) { NCTCStopPrompt.NotifyRequest(this.game, player.m_nctcHubChoiceLines[selected]); };
        NCTCStopPrompt.ClearHubChoice(player);
        return true;
      };
      return false;
    };
    if !Equals(name, n"one_click_confirm") || !ListenerAction.IsButtonJustReleased(action) || !player.m_nctcPromptVisible { return false; };
    settings = NCTCSettings.Get(this.game);
    if IsDefined(settings) && settings.ShouldRecordTerminalStops() {
      markers = NCTCMapMarkerSystem.GetInstance(this.game);
      if IsDefined(markers) && markers.GetNearestTravelAnchor(player.GetWorldPosition(), locKey, stop) { settings.RecordTerminalStop(locKey, stop); return true; };
      return false;
    };
    if !NCTCStopPrompt.IsNearStop(this.game, line, stop, stopIndex, stopId) { return false; };
    // Only metro hubs have a second level: the first action preserves room for
    // vanilla Metro/Fast Travel actions, then presents the NCTC lines.
    markers = NCTCMapMarkerSystem.GetInstance(this.game);
    if IsDefined(markers) && markers.IsNearMetroAnchor(player.GetWorldPosition()) && NCTCStopPrompt.StartHubChoice(this.game, player.GetWorldPosition()) {
      NCTCStopPrompt.SetVisible(this.game, true);
      player.m_nctcPromptVisible = true;
      return true;
    };
    if NCTCTransitSystem.Get(this.game).RequestService(line, stopId, stop) { NCTCStopPrompt.NotifyRequest(this.game, line); };
    return true;
  }
}

@addField(PlayerPuppet) private let m_nctcPromptInputListener: ref<NCTCStopPromptInputListener>;
@addField(PlayerPuppet) public let m_nctcPromptVisible: Bool;
@addField(PlayerPuppet) public let m_nctcHubChoiceActive: Bool;
@addField(PlayerPuppet) public let m_nctcHubChoiceIndex: Int32;
@addField(PlayerPuppet) public let m_nctcHubChoiceLines: array<String>;
@addField(PlayerPuppet) public let m_nctcHubChoiceStopIds: array<Int32>;
@addField(PlayerPuppet) public let m_nctcHubChoicePosition: Vector4;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let callback: ref<NCTCStopPromptCallback>;
  wrappedMethod(); this.m_nctcPromptInputListener = new NCTCStopPromptInputListener();
  this.m_nctcPromptInputListener.game = this.GetGame(); this.RegisterInputListener(this.m_nctcPromptInputListener);
  callback = new NCTCStopPromptCallback(); callback.game = this.GetGame();
  GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(callback, 0.10);
}
@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  if IsDefined(this.m_nctcPromptInputListener) { this.UnregisterInputListener(this.m_nctcPromptInputListener); this.m_nctcPromptInputListener = null; };
  NCTCStopPrompt.ClearHubChoice(this);
  NCTCStopPrompt.SetVisible(this.GetGame(), false); this.m_nctcPromptVisible = false; wrappedMethod();
}

@wrapMethod(DataTermControllerPS)
public const func GetActions(out actions: array<ref<DeviceAction>>, context: GetActionsContext) -> Bool {
  let result: Bool = wrappedMethod(actions, context); let settings: ref<NCTCSettings> = NCTCSettings.Get(this.GetGameInstance()); let line: String; let stop: Vector4; let stopIndex: Int32; let stopId: Int32; let index: Int32; let mapAction: ref<OpenWorldMapDeviceAction>;
  if !result { return result; };
  if IsDefined(settings) && settings.ShouldRecordTerminalStops() {
    if !NCTCStopPrompt.IsNearTravelTerminal(this.GetGameInstance()) { return result; };
  } else {
    if !NCTCStopPrompt.IsNearStop(this.GetGameInstance(), line, stop, stopIndex, stopId) { return result; };
    // Do not remove the native fast-travel action at a metro interchange.
    // It is part of the intended three-way interaction stack there.
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
    if IsDefined(markers) && markers.IsNearMetroAnchor(GetPlayer(this.GetGameInstance()).GetWorldPosition()) { return result; };
  };
  index = ArraySize(actions) - 1;
  while index >= 0 { mapAction = actions[index] as OpenWorldMapDeviceAction; if IsDefined(mapAction) { ArrayErase(actions, index); }; index -= 1; };
  return result;
}

@wrapMethod(DataTermInkGameController)
private func UpdatePointText() -> Void {
  let system: ref<NCTCMapMarkerSystem>; let lines: array<String>; let stops: array<String>;
  wrappedMethod(); if !IsDefined(this.m_point) { return; };
  system = NCTCMapMarkerSystem.GetInstance(this.GetOwner().GetGame());
  if IsDefined(system) && system.GetServicesForLocKey(this.m_point.GetPointDisplayName(), lines, stops) { this.m_pointText.SetText(NCTCStopPrompt.FormatTerminalTitle(lines, stops)); };
}
