module NCTC

import Codeware.UI.*

// NCTC Pocket Guide world-map flow.
// Architecture and interaction model adapted from DJ_Kovrik's Metro Pocket Guide
// with the author's permission. NCTC names/data are kept separate so both mods
// can coexist in the same load order.

public class NCTCBusGuideNode {
  public let line: Int32;
  public let stopId: Int32;
  public let sequence: Int32;
  public let locKey: Int32;
  public let position: Vector4;
  public let title: String;
}

public class NCTCBusGuideRoutePoint {
  public let line: Int32;
  public let stopId: Int32;
  public let title: String;
  public let position: Vector4;
  public let transfer: Bool;
}

public class NCTCBusGuideQueue {
  private let values: array<Int32>;

  public func Add(value: Int32) -> Void {
    ArrayPush(this.values, value);
  }

  public func IsNotEmpty() -> Bool {
    return ArraySize(this.values) > 0;
  }

  public func PopLeft() -> Int32 {
    let value: Int32;
    if ArraySize(this.values) == 0 { return -1; };
    value = this.values[0];
    ArrayErase(this.values, 0);
    return value;
  }
}

public class NCTCBusGuideNavigator extends ScriptableSystem {
  private let departureAnchor: String;
  private let departurePosition: Vector4;
  private let departureTitle: String;
  private let destinationAnchor: String;
  private let destinationPosition: Vector4;
  private let destinationTitle: String;
  private let route: array<ref<NCTCBusGuideRoutePoint>>;
  private let activeRoute: Bool;

  public static func GetInstance(game: GameInstance) -> ref<NCTCBusGuideNavigator> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<NCTCBusGuideNavigator>()) as NCTCBusGuideNavigator;
  }

  public func SaveDeparture(anchor: String, position: Vector4, title: String) -> Void {
    this.departureAnchor = anchor;
    this.departurePosition = position;
    this.departureTitle = title;
    this.activeRoute = false;
    ArrayClear(this.route);
  }

  public func SaveDestination(anchor: String, position: Vector4, title: String) -> Void {
    this.destinationAnchor = anchor;
    this.destinationPosition = position;
    this.destinationTitle = title;
    this.activeRoute = false;
    ArrayClear(this.route);
  }

  public func HasDeparture() -> Bool {
    return StrLen(this.departureTitle) > 0;
  }

  public func HasDestination() -> Bool {
    return StrLen(this.destinationTitle) > 0;
  }

  public func HasActiveRoute() -> Bool {
    return this.activeRoute && ArraySize(this.route) > 0;
  }

  public func GetDepartureTitle() -> String {
    return this.departureTitle;
  }

  public func GetDestinationTitle() -> String {
    return this.destinationTitle;
  }

  public func GetRoute() -> array<ref<NCTCBusGuideRoutePoint>> {
    return this.route;
  }

  public func Reset() -> Void {
    this.departureAnchor = "";
    this.destinationAnchor = "";
    this.departureTitle = "";
    this.destinationTitle = "";
    this.departurePosition = Vector4.EmptyVector();
    this.destinationPosition = Vector4.EmptyVector();
    this.activeRoute = false;
    ArrayClear(this.route);
  }

  private func PhysicalMatch(node: ref<NCTCBusGuideNode>, anchor: String, position: Vector4) -> Bool {
    if StrLen(anchor) > 0 && node.locKey > 0 {
      if Equals(anchor, "LocKey#" + ToString(node.locKey)) { return true; };
    };
    return Vector4.Distance2D(node.position, position) <= 22.00;
  }

  private func SamePhysical(a: ref<NCTCBusGuideNode>, b: ref<NCTCBusGuideNode>) -> Bool {
    if a.locKey > 0 && b.locKey > 0 && Equals(a.locKey, b.locKey) { return true; };
    return Vector4.Distance2D(a.position, b.position) <= 20.00;
  }

  private func SameLineAdjacent(nodes: array<ref<NCTCBusGuideNode>>, a: ref<NCTCBusGuideNode>, b: ref<NCTCBusGuideNode>) -> Bool {
    let low: Int32;
    let high: Int32;
    let index: Int32 = 0;
    if !Equals(a.line, b.line) || Equals(a.sequence, b.sequence) { return false; };
    if a.sequence < b.sequence { low = a.sequence; high = b.sequence; }
    else { low = b.sequence; high = a.sequence; };
    while index < ArraySize(nodes) {
      if Equals(nodes[index].line, a.line) && nodes[index].sequence > low && nodes[index].sequence < high {
        return false;
      };
      index += 1;
    };
    return true;
  }

  private func Adjacent(nodes: array<ref<NCTCBusGuideNode>>, a: ref<NCTCBusGuideNode>, b: ref<NCTCBusGuideNode>) -> Bool {
    if this.SameLineAdjacent(nodes, a, b) { return true; };
    if !Equals(a.line, b.line) && this.SamePhysical(a, b) { return true; };
    return false;
  }

  private func LoadNodes() -> array<ref<NCTCBusGuideNode>> {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let markerSystem: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
    let nodes: array<ref<NCTCBusGuideNode>>;
    let node: ref<NCTCBusGuideNode>;
    let count: Int32;
    let index: Int32 = 0;
    let prefix: String;
    let line: Int32;
    let locKey: Int32;
    if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_external_network_ready"), 1) { return nodes; };
    count = quests.GetFact(n"nctc_external_network_stop_count");
    while index < count {
      prefix = "nctc_external_stop_" + ToString(index) + "_";
      line = quests.GetFact(StringToName(prefix + "line"));
      if line > 0 && line < 100 {
        node = new NCTCBusGuideNode();
        node.line = line;
        node.stopId = quests.GetFact(StringToName(prefix + "id"));
        node.sequence = quests.GetFact(StringToName(prefix + "sequence"));
        node.locKey = quests.GetFact(StringToName(prefix + "loc_key"));
        node.position = new Vector4(
          Cast<Float>(quests.GetFact(StringToName(prefix + "x"))) / 1000.00,
          Cast<Float>(quests.GetFact(StringToName(prefix + "y"))) / 1000.00,
          Cast<Float>(quests.GetFact(StringToName(prefix + "z"))) / 1000.00,
          1.00
        );
        if node.locKey > 0 {
          node.title = GetLocalizedText("LocKey#" + ToString(node.locKey));
        } else if IsDefined(markerSystem) {
          node.title = markerSystem.GetSurveyStopName(node.line, node.sequence);
        } else {
          node.title = "Stop " + ToString(node.stopId);
        };
        ArrayPush(nodes, node);
      };
      index += 1;
    };
    return nodes;
  }

  public func BuildRoute() -> Bool {
    let nodes: array<ref<NCTCBusGuideNode>> = this.LoadNodes();
    let visited: array<Bool>;
    let previous: array<Int32>;
    let queue: ref<NCTCBusGuideQueue> = new NCTCBusGuideQueue();
    let path: array<Int32>;
    let reversed: array<Int32>;
    let point: ref<NCTCBusGuideRoutePoint>;
    let count: Int32 = ArraySize(nodes);
    let index: Int32 = 0;
    let scan: Int32;
    let current: Int32;
    let destinationIndex: Int32 = -1;
    let at: Int32;
    let previousLine: Int32 = -1;

    ArrayClear(this.route);
    this.activeRoute = false;
    if count == 0 || !this.HasDeparture() || !this.HasDestination() { return false; };

    while index < count {
      ArrayPush(visited, false);
      ArrayPush(previous, -1);
      index += 1;
    };

    index = 0;
    while index < count {
      if this.PhysicalMatch(nodes[index], this.departureAnchor, this.departurePosition) {
        visited[index] = true;
        previous[index] = -2;
        queue.Add(index);
      };
      index += 1;
    };

    while queue.IsNotEmpty() && destinationIndex < 0 {
      current = queue.PopLeft();
      if current < 0 { break; };
      if this.PhysicalMatch(nodes[current], this.destinationAnchor, this.destinationPosition) {
        destinationIndex = current;
        break;
      };
      scan = 0;
      while scan < count {
        if !visited[scan] && this.Adjacent(nodes, nodes[current], nodes[scan]) {
          visited[scan] = true;
          previous[scan] = current;
          queue.Add(scan);
        };
        scan += 1;
      };
    };

    if destinationIndex < 0 { return false; };

    at = destinationIndex;
    while at >= 0 {
      ArrayPush(reversed, at);
      if Equals(previous[at], -2) { break; };
      at = previous[at];
    };

    index = ArraySize(reversed) - 1;
    while index >= 0 {
      ArrayPush(path, reversed[index]);
      index -= 1;
    };

    index = 0;
    while index < ArraySize(path) {
      current = path[index];
      point = new NCTCBusGuideRoutePoint();
      point.line = nodes[current].line;
      point.stopId = nodes[current].stopId;
      point.title = nodes[current].title;
      point.position = nodes[current].position;
      point.transfer = previousLine > 0 && !Equals(previousLine, point.line);
      ArrayPush(this.route, point);
      previousLine = point.line;
      index += 1;
    };

    this.activeRoute = ArraySize(this.route) > 0;
    return this.activeRoute;
  }

  public func GetRouteSummary() -> String {
    let transfers: Int32 = 0;
    let index: Int32 = 0;
    let lastLine: Int32 = -1;
    let lineChain: String = "";
    while index < ArraySize(this.route) {
      if !Equals(this.route[index].line, lastLine) {
        if lastLine > 0 { transfers += 1; lineChain += " > "; };
        lineChain += "L" + ToString(this.route[index].line);
        lastLine = this.route[index].line;
      };
      index += 1;
    };
    return lineChain + "  //  " + ToString(ArraySize(this.route)) + " ARRÊTS  //  " + ToString(transfers) + " CORRESP.";
  }
}

public class NCTCBusGuideButton extends HubLinkButton {
  public static func Create() -> ref<NCTCBusGuideButton> {
    let self = new NCTCBusGuideButton();
    self.CreateInstance();
    return self;
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_icon.SetMargin(0.0, 30.0, 0.0, 6.0);
    this.m_icon.SetSize(Vector2(58.0, 46.0));
    this.m_icon.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
    this.m_icon.SetTexturePart(n"fast_travel");
  }

  public func SetVisible(visible: Bool) -> Void {
    this.m_root.SetVisible(visible);
  }
}

@addField(WorldMapMenuGameController)
let nctcRouteButtonsContainer: wref<inkWidget>;

@addField(WorldMapMenuGameController)
let nctcRouteButtonNavigate: wref<NCTCBusGuideButton>;

@addField(WorldMapMenuGameController)
let nctcRouteButtonCancel: wref<NCTCBusGuideButton>;

@addField(WorldMapMenuGameController)
let nctcRouteButtonConfirm: wref<NCTCBusGuideButton>;

@addField(WorldMapMenuGameController)
let nctcRouteButtonStop: wref<NCTCBusGuideButton>;

@addField(WorldMapMenuGameController)
let nctcRouteDepartureLabel: wref<inkText>;

@addField(WorldMapMenuGameController)
let nctcRouteDestinationLabel: wref<inkText>;

@addField(WorldMapMenuGameController)
let nctcRouteSummaryLabel: wref<inkText>;

@addField(WorldMapMenuGameController)
let nctcRouteSelectionEnabled: Bool;

@addField(WorldMapMenuGameController)
let nctcRouteHoveredController: wref<BaseWorldMapMappinController>;

@addField(WorldMapMenuGameController)
let nctcRouteNavigator: wref<NCTCBusGuideNavigator>;

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideMakeLabel(parent: ref<inkCompoundWidget>, name: CName, fontSize: Int32) -> ref<inkText> {
  let label: ref<inkText> = new inkText();
  label.SetName(name);
  label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  label.SetFontStyle(n"Medium");
  label.SetFontSize(fontSize);
  label.SetLetterCase(textLetterCase.OriginalCase);
  label.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
  label.BindProperty(n"tintColor", n"MainColors.Blue");
  label.SetHorizontalAlignment(textHorizontalAlignment.Center);
  label.SetVerticalAlignment(textVerticalAlignment.Center);
  label.SetContentHAlign(inkEHorizontalAlign.Center);
  label.SetContentVAlign(inkEVerticalAlign.Center);
  label.SetVisible(false);
  label.Reparent(parent);
  return label;
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideCreateMetroStyleUI() -> Void {
  let root: ref<inkCompoundWidget>;
  let parent: ref<inkCompoundWidget>;
  let buttons: ref<inkCompoundWidget>;
  let labels: ref<inkVerticalPanel>;
  if IsDefined(this.nctcRouteButtonNavigate) { return; };

  root = this.GetRootCompoundWidget();
  if !IsDefined(root) { return; };
  parent = root.GetWidgetByPathName(n"Content") as inkCompoundWidget;
  if !IsDefined(parent) { return; };

  buttons = new inkCanvas();
  buttons.SetName(n"NCTCBusGuideButtons");
  buttons.SetAnchor(inkEAnchor.BottomCenter);
  buttons.SetFitToContent(true);
  buttons.SetInteractive(false);
  buttons.SetAnchorPoint(0.5, 1.0);
  buttons.SetMargin(0.0, 0.0, 0.0, 320.0);
  buttons.Reparent(parent);
  this.nctcRouteButtonsContainer = buttons;

  this.nctcRouteButtonNavigate = NCTCBusGuideButton.Create();
  this.nctcRouteButtonNavigate.SetName(n"NCTCBusGuideNavigate");
  this.nctcRouteButtonNavigate.SetText("NCTC ITINÉRAIRE");
  this.nctcRouteButtonNavigate.RegisterToCallback(n"OnClick", this, n"OnNCTCBusGuideNavigate");
  this.nctcRouteButtonNavigate.Reparent(buttons);

  this.nctcRouteButtonCancel = NCTCBusGuideButton.Create();
  this.nctcRouteButtonCancel.SetName(n"NCTCBusGuideCancel");
  this.nctcRouteButtonCancel.SetText("ANNULER");
  this.nctcRouteButtonCancel.SetVisible(false);
  this.nctcRouteButtonCancel.RegisterToCallback(n"OnClick", this, n"OnNCTCBusGuideCancel");
  this.nctcRouteButtonCancel.Reparent(buttons);

  this.nctcRouteButtonConfirm = NCTCBusGuideButton.Create();
  this.nctcRouteButtonConfirm.SetName(n"NCTCBusGuideConfirm");
  this.nctcRouteButtonConfirm.SetText("CONFIRMER");
  this.nctcRouteButtonConfirm.SetVisible(false);
  this.nctcRouteButtonConfirm.RegisterToCallback(n"OnClick", this, n"OnNCTCBusGuideConfirm");
  this.nctcRouteButtonConfirm.Reparent(buttons);

  this.nctcRouteButtonStop = NCTCBusGuideButton.Create();
  this.nctcRouteButtonStop.SetName(n"NCTCBusGuideStop");
  this.nctcRouteButtonStop.SetText("ARRÊTER L’ITINÉRAIRE");
  this.nctcRouteButtonStop.SetVisible(false);
  this.nctcRouteButtonStop.RegisterToCallback(n"OnClick", this, n"OnNCTCBusGuideStop");
  this.nctcRouteButtonStop.Reparent(buttons);

  labels = new inkVerticalPanel();
  labels.SetName(n"NCTCBusGuideSelectionLabels");
  labels.SetAnchor(inkEAnchor.BottomCenter);
  labels.SetFitToContent(true);
  labels.SetInteractive(false);
  labels.SetAnchorPoint(0.5, 1.0);
  labels.SetMargin(0.0, 0.0, 0.0, 382.0);
  labels.Reparent(parent);

  this.nctcRouteDepartureLabel = this.NCTCGuideMakeLabel(labels, n"NCTCBusGuideFrom", 34);
  this.nctcRouteDestinationLabel = this.NCTCGuideMakeLabel(labels, n"NCTCBusGuideTo", 34);
  this.nctcRouteSummaryLabel = this.NCTCGuideMakeLabel(labels, n"NCTCBusGuideSummary", 28);

  this.nctcRouteNavigator = NCTCBusGuideNavigator.GetInstance(this.GetPlayerControlledObject().GetGame());
  this.NCTCGuideRefreshState();
}

@wrapMethod(WorldMapMenuGameController)
protected cb func OnEntityAttached() -> Bool {
  let result: Bool = wrappedMethod();
  this.NCTCGuideCreateMetroStyleUI();
  return result;
}

@wrapMethod(WorldMapMenuGameController)
protected cb func OnUninitialize() -> Bool {
  if IsDefined(this.nctcRouteNavigator) && !this.nctcRouteNavigator.HasActiveRoute() {
    this.nctcRouteNavigator.Reset();
  };
  return wrappedMethod();
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideShowOnly(mode: Int32) -> Void {
  this.nctcRouteButtonNavigate.SetVisible(Equals(mode, 0));
  this.nctcRouteButtonCancel.SetVisible(Equals(mode, 1));
  this.nctcRouteButtonConfirm.SetVisible(Equals(mode, 2));
  this.nctcRouteButtonStop.SetVisible(Equals(mode, 3));
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideRefreshState() -> Void {
  if !IsDefined(this.nctcRouteNavigator) { return; };
  if this.nctcRouteNavigator.HasActiveRoute() {
    this.NCTCGuideShowOnly(3);
    this.nctcRouteDepartureLabel.SetText("DE : " + this.nctcRouteNavigator.GetDepartureTitle());
    this.nctcRouteDestinationLabel.SetText("À : " + this.nctcRouteNavigator.GetDestinationTitle());
    this.nctcRouteSummaryLabel.SetText(this.nctcRouteNavigator.GetRouteSummary());
    this.nctcRouteDepartureLabel.SetVisible(true);
    this.nctcRouteDestinationLabel.SetVisible(true);
    this.nctcRouteSummaryLabel.SetVisible(true);
  } else {
    this.NCTCGuideShowOnly(0);
    this.nctcRouteDepartureLabel.SetVisible(false);
    this.nctcRouteDestinationLabel.SetVisible(false);
    this.nctcRouteSummaryLabel.SetVisible(false);
  };
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideBeginSelection() -> Void {
  this.nctcRouteNavigator.Reset();
  this.nctcRouteSelectionEnabled = true;
  this.NCTCGuideShowOnly(1);
  this.nctcRouteDepartureLabel.SetText("SÉLECTIONNEZ L’ARRÊT DE DÉPART");
  this.nctcRouteDestinationLabel.SetText(" ");
  this.nctcRouteSummaryLabel.SetText("NCTC // CHOIX D’ITINÉRAIRE");
  this.nctcRouteDepartureLabel.SetVisible(true);
  this.nctcRouteDestinationLabel.SetVisible(true);
  this.nctcRouteSummaryLabel.SetVisible(true);
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideCancelSelection() -> Void {
  this.nctcRouteSelectionEnabled = false;
  this.nctcRouteNavigator.Reset();
  this.NCTCGuideRefreshState();
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideStopRoute() -> Void {
  this.nctcRouteSelectionEnabled = false;
  this.nctcRouteNavigator.Reset();
  this.NCTCGuideRefreshState();
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideConfirmRoute() -> Void {
  if this.nctcRouteNavigator.BuildRoute() {
    this.nctcRouteSelectionEnabled = false;
    this.NCTCGuideRefreshState();
  } else {
    this.nctcRouteSummaryLabel.SetText("AUCUN ITINÉRAIRE NCTC TROUVÉ");
  };
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCBusGuideNavigate(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(n"click") {
    this.PlaySound(n"Button", n"OnPress");
    this.NCTCGuideBeginSelection();
    evt.Handle();
    return true;
  };
  return false;
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCBusGuideCancel(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(n"click") {
    this.PlaySound(n"Button", n"OnPress");
    this.NCTCGuideCancelSelection();
    evt.Handle();
    return true;
  };
  return false;
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCBusGuideConfirm(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(n"click") {
    this.PlaySound(n"Button", n"OnPress");
    this.NCTCGuideConfirmRoute();
    evt.Handle();
    return true;
  };
  return false;
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCBusGuideStop(evt: ref<inkPointerEvent>) -> Bool {
  if evt.IsAction(n"click") {
    this.PlaySound(n"Button", n"OnPress");
    this.NCTCGuideStopRoute();
    evt.Handle();
    return true;
  };
  return false;
}

@wrapMethod(WorldMapMenuGameController)
protected cb func OnHoverOverMappin(evt: ref<inkPointerEvent>) -> Bool {
  this.nctcRouteHoveredController = evt.GetTarget().GetController() as BaseWorldMapMappinController;
  return wrappedMethod(evt);
}

@wrapMethod(WorldMapMenuGameController)
protected cb func OnHoverOutMappin(evt: ref<inkPointerEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  this.nctcRouteHoveredController = null;
  return result;
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideSelectedStopTitle(data: ref<NCTCStopMappinData>) -> String {
  if StrLen(data.anchorLocKey) > 0 { return GetLocalizedText(data.anchorLocKey); };
  if ArraySize(data.serviceStops) > 0 { return data.serviceStops[0]; };
  return data.services;
}

@wrapMethod(WorldMapMenuGameController)
private final func HandlePressInput(evt: ref<inkPointerEvent>) -> Void {
  let controller: ref<BaseWorldMapMappinController> = this.nctcRouteHoveredController;
  let stopData: ref<NCTCStopMappinData>;
  let position: Vector4;
  let title: String;

  if evt.IsAction(n"click") && this.nctcRouteSelectionEnabled && IsDefined(controller) {
    stopData = controller.GetMappin().GetScriptData() as NCTCStopMappinData;
    if IsDefined(stopData) && !Equals(stopData.line, "PASSAGE") {
      position = controller.GetMappin().GetWorldPosition();
      title = this.NCTCGuideSelectedStopTitle(stopData);
      this.PlaySound(n"Button", n"OnPress");

      if !this.nctcRouteNavigator.HasDeparture() {
        this.nctcRouteNavigator.SaveDeparture(stopData.anchorLocKey, position, title);
        this.nctcRouteDepartureLabel.SetText("DE : " + title);
        this.nctcRouteDestinationLabel.SetText("SÉLECTIONNEZ LA DESTINATION");
      } else {
        this.nctcRouteNavigator.SaveDestination(stopData.anchorLocKey, position, title);
        this.nctcRouteDestinationLabel.SetText("À : " + title);
        this.nctcRouteSummaryLabel.SetText("ITINÉRAIRE PRÊT À CALCULER");
        this.NCTCGuideShowOnly(2);
      };

      evt.Handle();
      return;
    };
  };

  wrappedMethod(evt);
}
