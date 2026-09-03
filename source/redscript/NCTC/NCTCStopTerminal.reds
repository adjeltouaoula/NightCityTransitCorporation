module NCTC

// Native HUD prompt, independent from the fast-travel DataTerm widget.
public class NCTCStopPrompt {
  public static func FormatTerminalTitle(lines: array<String>, stops: array<String>) -> String {
    let index: Int32 = 1;
    let title: String;
    if ArraySize(lines) == 1 { return stops[0] + "\nNCTC • LIGNE " + lines[0]; };
    title = stops[0] + "\nTRANSFER: " + lines[0];
    while index < ArraySize(lines) {
      title += " · " + lines[index];
      index += 1;
    };
    return title;
  }

  public static func IsNearStop(game: GameInstance, out line: String, out stop: Vector4) -> Bool {
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let markers: ref<NCTCMapMarkerSystem>;
    if !IsDefined(player) { return false; };
    markers = NCTCMapMarkerSystem.GetInstance(game);
    if !IsDefined(markers) || !markers.GetNearestService(player.GetWorldPosition(), line, stop) { return false; };
    return Vector4.Distance(player.GetWorldPosition(), stop) <= 6.00;
  }

  public static func FormatTitle(game: GameInstance) -> String {
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(game);
    let lines: array<String>;
    let stops: array<String>;
    let index: Int32 = 1;
    let title: String;
    if !IsDefined(player) || !IsDefined(markers) || !markers.GetNearestStopServices(player.GetWorldPosition(), lines, stops) {
      return "Attendre le bus";
    };
    if ArraySize(lines) == 1 {
      return "Ligne " + lines[0] + " — " + stops[0];
    };
    title = "Correspondance — lignes " + lines[0];
    while index < ArraySize(lines) {
      title += ", " + lines[index];
      index += 1;
    };
    return title;
  }

  public static func SetVisible(game: GameInstance, visible: Bool) -> Void {
    let hub: InteractionChoiceHubData;
    let choice: InteractionChoiceData;
    let choiceType: ChoiceTypeWrapper;
    let visualizers: VisualizersInfo;
    let defs: ref<AllBlackboardDefinitions>;
    let blackboard: ref<IBlackboard>;
    hub.id = -12017;
    hub.active = visible;
    hub.flags = IntEnum<EVisualizerDefinitionFlags>(0);
    hub.title = NCTCStopPrompt.FormatTitle(game);
    choice.localizedName = "Attendre le bus";
    choice.inputAction = n"UI_Apply";
    ChoiceTypeWrapper.SetType(choiceType, gameinteractionsChoiceType.Blueline);
    choice.type = choiceType;
    hub.choices = [choice];
    visualizers.activeVisId = hub.id;
    visualizers.visIds = [hub.id];
    defs = GetAllBlackboardDefs();
    blackboard = GameInstance.GetBlackboardSystem(game).Get(defs.UIInteractions);
    blackboard.SetVariant(defs.UIInteractions.InteractionChoiceHub, ToVariant(hub), true);
    blackboard.SetVariant(defs.UIInteractions.VisualizersInfo, ToVariant(visualizers), true);
  }

  public static func Refresh(game: GameInstance) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let line: String;
    let stop: Vector4;
    let visible: Bool = NCTCStopPrompt.IsNearStop(game, line, stop);
    if !IsDefined(player) { return; };
    // A nearby DataTerm refreshes the same UIInteractions blackboard every
    // frame. Re-publish while visible so its empty action list cannot erase
    // the NCTC prompt as V reaches the physical terminal.
    if visible || !Equals(player.m_nctcPromptVisible, visible) {
      NCTCStopPrompt.SetVisible(game, visible);
    };
    player.m_nctcPromptVisible = visible;
  }
}

public class NCTCStopPromptCallback extends DelayCallback {
  public let game: GameInstance;
  public func Call() -> Void {
    let next: ref<NCTCStopPromptCallback> = new NCTCStopPromptCallback();
    NCTCStopPrompt.Refresh(this.game);
    next.game = this.game;
    GameInstance.GetDelaySystem(this.game).DelayCallback(next, 0.10);
  }
}

public class NCTCStopPromptInputListener {
  public let game: GameInstance;
  protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    let player: ref<PlayerPuppet>;
    let line: String;
    let stop: Vector4;
    if !Equals(ListenerAction.GetName(action), n"one_click_confirm") || !ListenerAction.IsButtonJustReleased(action) { return false; };
    player = GetPlayer(this.game);
    if !IsDefined(player) || !player.m_nctcPromptVisible || !NCTCStopPrompt.IsNearStop(this.game, line, stop) { return false; };
    NCTCTransitSystem.Get(this.game).RequestService(line, stop);
    return true;
  }
}

@addField(PlayerPuppet)
private let m_nctcPromptInputListener: ref<NCTCStopPromptInputListener>;

@addField(PlayerPuppet)
public let m_nctcPromptVisible: Bool;

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let callback: ref<NCTCStopPromptCallback>;
  wrappedMethod();
  this.m_nctcPromptInputListener = new NCTCStopPromptInputListener();
  this.m_nctcPromptInputListener.game = this.GetGame();
  this.RegisterInputListener(this.m_nctcPromptInputListener);
  callback = new NCTCStopPromptCallback();
  callback.game = this.GetGame();
  GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(callback, 0.10);
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  if IsDefined(this.m_nctcPromptInputListener) {
    this.UnregisterInputListener(this.m_nctcPromptInputListener);
    this.m_nctcPromptInputListener = null;
  };
  NCTCStopPrompt.SetVisible(this.GetGame(), false);
  this.m_nctcPromptVisible = false;
  wrappedMethod();
}

@wrapMethod(DataTermControllerPS)
public const func GetActions(out actions: array<ref<DeviceAction>>, context: GetActionsContext) -> Bool {
  let result: Bool = wrappedMethod(actions, context);
  let line: String;
  let stop: Vector4;
  let index: Int32;
  let mapAction: ref<OpenWorldMapDeviceAction>;
  if !result || !NCTCStopPrompt.IsNearStop(this.GetGameInstance(), line, stop) { return result; };
  index = ArraySize(actions) - 1;
  while index >= 0 {
    mapAction = actions[index] as OpenWorldMapDeviceAction;
    if IsDefined(mapAction) { ArrayErase(actions, index); };
    index -= 1;
  };
  return result;
}

// The title on the physical DataTerm screen is separate from its interaction
// widget.  Keep all non-NCTC terminals untouched, then replace only the
// screen's point-name label when its linked fast-travel point is an NCTC stop.
@wrapMethod(DataTermInkGameController)
private func UpdatePointText() -> Void {
  let system: ref<NCTCMapMarkerSystem>;
  let lines: array<String>;
  let stops: array<String>;
  wrappedMethod();
  if !IsDefined(this.m_point) { return; };
  system = NCTCMapMarkerSystem.GetInstance(this.GetOwner().GetGame());
  if IsDefined(system) && system.GetServicesForLocKey(this.m_point.GetPointDisplayName(), lines, stops) {
    this.m_pointText.SetText(NCTCStopPrompt.FormatTerminalTitle(lines, stops));
  };
}
