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

  public static func IsHubChoiceOpen(game: GameInstance) -> Bool {
    return Equals(GameInstance.GetQuestsSystem(game).GetFact(n"nctc_hub_choice_open"), 1);
  }

  private static func OpenHubChoice(game: GameInstance, position: Vector4) -> Bool {
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(game);
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let lines: array<String>;
    let stopIds: array<Int32>;
    let stop: Vector4;
    let index: Int32 = 0;
    if !IsDefined(markers) || !IsDefined(quests) || !markers.GetNearestServiceChoices(position, lines, stopIds, stop) || ArraySize(lines) < 2 { return false; };
    quests.SetFact(n"nctc_hub_choice_count", ArraySize(lines));
    quests.SetFact(n"nctc_hub_choice_x", Cast<Int32>(stop.X * 1000.00));
    quests.SetFact(n"nctc_hub_choice_y", Cast<Int32>(stop.Y * 1000.00));
    quests.SetFact(n"nctc_hub_choice_z", Cast<Int32>(stop.Z * 1000.00));
    while index < ArraySize(lines) {
      quests.SetFact(StringToName("nctc_hub_choice_" + ToString(index) + "_line"), StringToInt(lines[index], -1));
      quests.SetFact(StringToName("nctc_hub_choice_" + ToString(index) + "_stop_id"), stopIds[index]);
      index += 1;
    };
    quests.SetFact(n"nctc_hub_choice_open", 1);
    quests.SetFact(n"nctc_hub_choice_revision", quests.GetFact(n"nctc_hub_choice_revision") + 1);
    return true;
  }

  public static func SetVisible(game: GameInstance, visible: Bool) -> Void {
    let hub: InteractionChoiceHubData;
    let choice: InteractionChoiceData;
    let choiceType: ChoiceTypeWrapper;
    let visualizers: VisualizersInfo;
    let defs: ref<AllBlackboardDefinitions>;
    let blackboard: ref<IBlackboard>;
    hub.id = -12017; hub.active = visible; hub.flags = IntEnum<EVisualizerDefinitionFlags>(0);
    hub.title = NCTCStopPrompt.FormatTitle(game);
    if IsDefined(NCTCSettings.Get(game)) && NCTCSettings.Get(game).ShouldRecordTerminalStops() {
      hub.title = "NCTC DEV";
      choice.localizedName = "Enregistrer l arret";
    } else { choice.localizedName = "Attendre le bus"; };
    choice.inputAction = n"UI_Apply";
    ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Blueline);
    choice.type = choiceType; hub.choices = [choice];
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
    let visible: Bool = !NCTCStopPrompt.IsHubChoiceOpen(game) && (IsDefined(settings) && settings.ShouldRecordTerminalStops() ? NCTCStopPrompt.IsNearTravelTerminal(game) : NCTCStopPrompt.IsNearStop(game, line, stop, stopIndex, stopId));
    if !IsDefined(player) { return; };
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
    let player: ref<PlayerPuppet>; let settings: ref<NCTCSettings>; let markers: ref<NCTCMapMarkerSystem>; let line: String; let locKey: String; let stop: Vector4; let stopIndex: Int32; let stopId: Int32;
    if !Equals(ListenerAction.GetName(action), n"one_click_confirm") || !ListenerAction.IsButtonJustReleased(action) { return false; };
    player = GetPlayer(this.game);
    if !IsDefined(player) || !player.m_nctcPromptVisible { return false; };
    settings = NCTCSettings.Get(this.game);
    if IsDefined(settings) && settings.ShouldRecordTerminalStops() {
      markers = NCTCMapMarkerSystem.GetInstance(this.game);
      if IsDefined(markers) && markers.GetNearestTravelAnchor(player.GetWorldPosition(), locKey, stop) { settings.RecordTerminalStop(locKey, stop); return true; };
      return false;
    };
    if NCTCStopPrompt.IsHubChoiceOpen(this.game) { return true; };
    if !NCTCStopPrompt.IsNearStop(this.game, line, stop, stopIndex, stopId) { return false; };
    if NCTCStopPrompt.OpenHubChoice(this.game, player.GetWorldPosition()) {
      NCTCStopPrompt.SetVisible(this.game, false);
      player.m_nctcPromptVisible = false;
      return true;
    };
    if NCTCTransitSystem.Get(this.game).RequestService(line, stopId, stop) { NCTCStopPrompt.NotifyRequest(this.game, line); };
    return true;
  }
}

@addField(PlayerPuppet) private let m_nctcPromptInputListener: ref<NCTCStopPromptInputListener>;
@addField(PlayerPuppet) public let m_nctcPromptVisible: Bool;

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
