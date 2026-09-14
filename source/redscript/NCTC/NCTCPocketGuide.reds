module NCTC

import Codeware.UI.*

// Native world-map pocket guide. Player-facing UI is pure Ink/REDscript and
// reads the same published network facts as the rest of NCTC.
public class NCTCGuideButton extends HubLinkButton {
  public static func Create() -> ref<NCTCGuideButton> {
    let self = new NCTCGuideButton();
    self.CreateInstance();
    return self;
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_icon.SetVisible(false);
    this.m_root.SetSize(Vector2(260.00, 58.00));
  }

  public func SetVisible(visible: Bool) -> Void {
    this.m_root.SetVisible(visible);
  }
}

public class NCTCGuideLineButton extends HubLinkButton {
  private let m_line: Int32;

  public static func Create(line: Int32) -> ref<NCTCGuideLineButton> {
    let self = new NCTCGuideLineButton();
    self.m_line = line;
    self.CreateInstance();
    return self;
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_icon.SetVisible(false);
    this.m_root.SetSize(Vector2(190.00, 56.00));
  }

  public func GetLine() -> Int32 {
    return this.m_line;
  }

  public func SetSelected(selected: Bool) -> Void {
    this.m_root.SetOpacity(selected ? 1.00 : 0.52);
  }
}

@addField(WorldMapMenuGameController)
let nctcGuideButton: wref<NCTCGuideButton>;

@addField(WorldMapMenuGameController)
let nctcGuideButtonContainer: wref<inkCanvas>;

@addField(WorldMapMenuGameController)
let nctcGuidePanel: wref<inkCanvas>;

@addField(WorldMapMenuGameController)
let nctcGuideLinePanel: wref<inkVerticalPanel>;

@addField(WorldMapMenuGameController)
let nctcGuideRoutePanel: wref<inkVerticalPanel>;

@addField(WorldMapMenuGameController)
let nctcGuideLineButtons: array<ref<NCTCGuideLineButton>>;

@addField(WorldMapMenuGameController)
let nctcGuideRouteTitle: wref<inkText>;

@addField(WorldMapMenuGameController)
let nctcGuideRouteMeta: wref<inkText>;

@addField(WorldMapMenuGameController)
let nctcGuideStatus: wref<inkText>;

@addField(WorldMapMenuGameController)
let nctcGuideAccent: wref<inkRectangle>;

@addField(WorldMapMenuGameController)
let nctcGuideVisible: Bool;

@addField(WorldMapMenuGameController)
let nctcGuideSelectedLine: Int32;

@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  wrappedMethod();
  this.NCTCCreatePocketGuide();
}

@addMethod(WorldMapMenuGameController)
private final func NCTCCreatePocketGuide() -> Void {
  let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  let parent: ref<inkCompoundWidget>;
  let background: ref<inkRectangle>;
  let topRail: ref<inkRectangle>;
  let redRail: ref<inkRectangle>;
  let divider: ref<inkRectangle>;
  let lineHeader: ref<inkText>;
  let brand: ref<inkText>;
  let subtitle: ref<inkText>;
  let footer: ref<inkText>;

  if !IsDefined(root) { return; };
  parent = root.GetWidgetByPathName(n"Content") as inkCompoundWidget;
  if !IsDefined(parent) { return; };

  this.nctcGuideButtonContainer = new inkCanvas();
  this.nctcGuideButtonContainer.SetName(n"NCTCGuideButtonContainer");
  this.nctcGuideButtonContainer.SetAnchor(inkEAnchor.BottomRight);
  this.nctcGuideButtonContainer.SetAnchorPoint(1.00, 1.00);
  this.nctcGuideButtonContainer.SetMargin(inkMargin(0.00, 0.00, 70.00, 110.00));
  this.nctcGuideButtonContainer.SetSize(Vector2(280.00, 70.00));
  this.nctcGuideButtonContainer.SetInteractive(false);
  this.nctcGuideButtonContainer.Reparent(parent);

  this.nctcGuideButton = NCTCGuideButton.Create();
  this.nctcGuideButton.SetName(n"NCTCGuideToggle");
  this.nctcGuideButton.SetText("NCTC GUIDE");
  this.nctcGuideButton.RegisterToCallback(n"OnClick", this, n"OnNCTCGuideToggle");
  this.nctcGuideButton.Reparent(this.nctcGuideButtonContainer);

  this.nctcGuidePanel = new inkCanvas();
  this.nctcGuidePanel.SetName(n"NCTCPocketGuidePanel");
  this.nctcGuidePanel.SetAnchor(inkEAnchor.TopRight);
  this.nctcGuidePanel.SetAnchorPoint(1.00, 0.00);
  this.nctcGuidePanel.SetMargin(inkMargin(0.00, 88.00, 58.00, 0.00));
  this.nctcGuidePanel.SetSize(Vector2(880.00, 840.00));
  this.nctcGuidePanel.SetInteractive(true);
  this.nctcGuidePanel.SetVisible(false);
  this.nctcGuidePanel.Reparent(parent);

  background = new inkRectangle();
  background.SetName(n"NCTCGuideBackground");
  background.SetSize(Vector2(880.00, 840.00));
  background.SetTintColor(HDRColor(0.006, 0.010, 0.014, 0.96));
  background.Reparent(this.nctcGuidePanel);

  topRail = new inkRectangle();
  topRail.SetSize(Vector2(880.00, 5.00));
  topRail.SetTintColor(HDRColor(0.20, 0.95, 1.35, 1.00));
  topRail.Reparent(this.nctcGuidePanel);

  redRail = new inkRectangle();
  redRail.SetMargin(inkMargin(0.00, 5.00, 0.00, 0.00));
  redRail.SetSize(Vector2(182.00, 3.00));
  redRail.SetTintColor(HDRColor(2.20, 0.16, 0.14, 1.00));
  redRail.Reparent(this.nctcGuidePanel);

  brand = this.NCTCGuideText(this.nctcGuidePanel, "NIGHT CITY TRANSIT CORPORATION", 38, 38.00, 26.00, 720.00, 56.00, HDRColor(0.32, 1.25, 1.55, 1.00));
  brand.SetFontStyle(n"Semi-Bold");

  subtitle = this.NCTCGuideText(this.nctcGuidePanel, "POCKET GUIDE // PUBLIC BUS NETWORK", 22, 40.00, 82.00, 720.00, 40.00, HDRColor(1.70, 0.20, 0.18, 1.00));
  subtitle.SetLetterCase(textLetterCase.UpperCase);

  this.nctcGuideStatus = this.NCTCGuideText(this.nctcGuidePanel, "NETWORK OFFLINE", 18, 40.00, 123.00, 720.00, 32.00, HDRColor(0.55, 0.62, 0.66, 1.00));

  divider = new inkRectangle();
  divider.SetMargin(inkMargin(235.00, 178.00, 0.00, 0.00));
  divider.SetSize(Vector2(2.00, 590.00));
  divider.SetTintColor(HDRColor(0.10, 0.28, 0.34, 0.75));
  divider.Reparent(this.nctcGuidePanel);

  lineHeader = this.NCTCGuideText(this.nctcGuidePanel, "LINES", 20, 38.00, 175.00, 180.00, 34.00, HDRColor(0.36, 1.10, 1.28, 1.00));
  lineHeader.SetLetterCase(textLetterCase.UpperCase);

  this.nctcGuideLinePanel = new inkVerticalPanel();
  this.nctcGuideLinePanel.SetName(n"NCTCGuideLines");
  this.nctcGuideLinePanel.SetMargin(inkMargin(35.00, 215.00, 0.00, 0.00));
  this.nctcGuideLinePanel.SetSize(Vector2(190.00, 500.00));
  this.nctcGuideLinePanel.SetFitToContent(true);
  this.nctcGuideLinePanel.SetChildMargin(inkMargin(0.00, 0.00, 0.00, 8.00));
  this.nctcGuideLinePanel.Reparent(this.nctcGuidePanel);

  this.nctcGuideAccent = new inkRectangle();
  this.nctcGuideAccent.SetMargin(inkMargin(267.00, 183.00, 0.00, 0.00));
  this.nctcGuideAccent.SetSize(Vector2(8.00, 66.00));
  this.nctcGuideAccent.SetTintColor(HDRColor(2.00, 0.26, 0.18, 1.00));
  this.nctcGuideAccent.Reparent(this.nctcGuidePanel);

  this.nctcGuideRouteTitle = this.NCTCGuideText(this.nctcGuidePanel, "SELECT A LINE", 34, 292.00, 178.00, 540.00, 48.00, HDRColor(0.92, 0.96, 0.98, 1.00));
  this.nctcGuideRouteTitle.SetFontStyle(n"Semi-Bold");

  this.nctcGuideRouteMeta = this.NCTCGuideText(this.nctcGuidePanel, "--", 18, 294.00, 222.00, 535.00, 30.00, HDRColor(0.48, 0.60, 0.65, 1.00));

  this.nctcGuideRoutePanel = new inkVerticalPanel();
  this.nctcGuideRoutePanel.SetName(n"NCTCGuideRoute");
  this.nctcGuideRoutePanel.SetMargin(inkMargin(286.00, 268.00, 0.00, 0.00));
  this.nctcGuideRoutePanel.SetSize(Vector2(540.00, 500.00));
  this.nctcGuideRoutePanel.SetFitToContent(true);
  this.nctcGuideRoutePanel.Reparent(this.nctcGuidePanel);

  footer = this.NCTCGuideText(this.nctcGuidePanel, "NCTC // MOVE NIGHT CITY", 17, 38.00, 792.00, 790.00, 28.00, HDRColor(0.28, 0.52, 0.58, 1.00));
  footer.SetLetterCase(textLetterCase.UpperCase);
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideText(parent: ref<inkCompoundWidget>, value: String, size: Int32, x: Float, y: Float, width: Float, height: Float, color: HDRColor) -> ref<inkText> {
  let text: ref<inkText> = new inkText();
  text.SetText(value);
  text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  text.SetFontStyle(n"Medium");
  text.SetFontSize(size);
  text.SetLetterCase(textLetterCase.OriginalCase);
  text.SetMargin(inkMargin(x, y, 0.00, 0.00));
  text.SetSize(Vector2(width, height));
  text.SetFitToContent(false);
  text.SetWrapping(false, width, textWrappingPolicy.PerCharacter);
  text.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
  text.SetHorizontalAlignment(textHorizontalAlignment.Left);
  text.SetVerticalAlignment(textVerticalAlignment.Center);
  text.SetContentHAlign(inkEHorizontalAlign.Left);
  text.SetContentVAlign(inkEVerticalAlign.Center);
  text.SetTintColor(color);
  text.Reparent(parent);
  return text;
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCGuideToggle(evt: ref<inkPointerEvent>) -> Bool {
  if !evt.IsAction(n"click") { return false; };
  this.PlaySound(n"Button", n"OnPress");
  this.nctcGuideVisible = !this.nctcGuideVisible;
  this.nctcGuidePanel.SetVisible(this.nctcGuideVisible);
  this.nctcGuideButton.SetText(this.nctcGuideVisible ? "CLOSE NCTC GUIDE" : "NCTC GUIDE");
  if this.nctcGuideVisible { this.NCTCGuideReload(); };
  evt.Handle();
  return true;
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCGuideLine(evt: ref<inkPointerEvent>) -> Bool {
  let controller: ref<NCTCGuideLineButton>;
  if !evt.IsAction(n"click") { return false; };
  controller = evt.GetTarget().GetController() as NCTCGuideLineButton;
  if !IsDefined(controller) { return false; };
  this.PlaySound(n"Button", n"OnPress");
  this.nctcGuideSelectedLine = controller.GetLine();
  this.NCTCGuideRefreshLine();
  evt.Handle();
  return true;
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideReload() -> Void {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetPlayerControlledObject().GetGame());
  let lines: array<Int32>;
  let button: ref<NCTCGuideLineButton>;
  let count: Int32;
  let index: Int32 = 0;
  let line: Int32;
  let scan: Int32;
  let swap: Int32;

  this.nctcGuideLinePanel.RemoveAllChildren();
  ArrayClear(this.nctcGuideLineButtons);
  this.nctcGuideRoutePanel.RemoveAllChildren();

  if !IsDefined(quests) || NotEquals(quests.GetFact(n"nctc_external_network_ready"), 1) {
    this.nctcGuideStatus.SetText("NETWORK OFFLINE // LOAD A SAVE");
    this.nctcGuideRouteTitle.SetText("NCTC DATA UNAVAILABLE");
    this.nctcGuideRouteMeta.SetText("The transit runtime has not published the network yet.");
    return;
  };

  count = quests.GetFact(n"nctc_external_network_stop_count");
  while index < count {
    line = quests.GetFact(StringToName("nctc_external_stop_" + ToString(index) + "_line"));
    // Current development-only routes use 100+ / 900+ numbers. Hide them from
    // the passenger guide until the network schema gains a public/dev flag.
    if line > 0 && line < 100 && !ArrayContains(lines, line) { ArrayPush(lines, line); };
    index += 1;
  };

  index = 0;
  while index < ArraySize(lines) {
    scan = index + 1;
    while scan < ArraySize(lines) {
      if lines[scan] < lines[index] {
        swap = lines[index];
        lines[index] = lines[scan];
        lines[scan] = swap;
      };
      scan += 1;
    };
    index += 1;
  };

  if ArraySize(lines) == 0 {
    this.nctcGuideStatus.SetText("NO PUBLIC LINES PUBLISHED");
    this.nctcGuideRouteTitle.SetText("SERVICE UNAVAILABLE");
    this.nctcGuideRouteMeta.SetText("No passenger services were found in the active network.");
    return;
  };

  if !ArrayContains(lines, this.nctcGuideSelectedLine) { this.nctcGuideSelectedLine = lines[0]; };

  for line in lines {
    button = NCTCGuideLineButton.Create(line);
    button.SetName(StringToName("NCTCGuideLine" + ToString(line)));
    button.SetText("LINE " + ToString(line));
    button.SetSelected(Equals(line, this.nctcGuideSelectedLine));
    button.RegisterToCallback(n"OnClick", this, n"OnNCTCGuideLine");
    button.Reparent(this.nctcGuideLinePanel);
    ArrayPush(this.nctcGuideLineButtons, button);
  };

  this.nctcGuideStatus.SetText("LIVE NETWORK // REV " + ToString(quests.GetFact(n"nctc_external_network_revision")));
  this.NCTCGuideRefreshLine();
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideRefreshLine() -> Void {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetPlayerControlledObject().GetGame());
  let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetPlayerControlledObject().GetGame());
  let count: Int32;
  let selectedCount: Int32 = 0;
  let index: Int32 = 0;
  let ordinal: Int32 = 0;
  let line: Int32;
  let prefix: String;
  let stopName: String;
  let firstName: String = "";
  let lastName: String = "";
  let transferCount: Int32 = 0;
  let transfers: String;
  let button: ref<NCTCGuideLineButton>;
  let colorIndex: Int32;

  if !IsDefined(quests) { return; };
  this.nctcGuideRoutePanel.RemoveAllChildren();

  for button in this.nctcGuideLineButtons {
    button.SetSelected(Equals(button.GetLine(), this.nctcGuideSelectedLine));
  };

  colorIndex = quests.GetFact(StringToName("nctc_external_line_" + ToString(this.nctcGuideSelectedLine) + "_color"));
  this.nctcGuideAccent.SetTintColor(this.NCTCGuideLineColor(colorIndex));

  count = quests.GetFact(n"nctc_external_network_stop_count");
  while index < count {
    if Equals(quests.GetFact(StringToName("nctc_external_stop_" + ToString(index) + "_line")), this.nctcGuideSelectedLine) {
      selectedCount += 1;
    };
    index += 1;
  };

  index = 0;
  while index < count {
    prefix = "nctc_external_stop_" + ToString(index) + "_";
    line = quests.GetFact(StringToName(prefix + "line"));
    if Equals(line, this.nctcGuideSelectedLine) {
      ordinal += 1;
      stopName = IsDefined(markers) ? markers.GetSurveyStopName(line, ordinal) : this.NCTCGuideFallbackName(quests, prefix);
      if Equals(firstName, "") { firstName = stopName; };
      lastName = stopName;
      transfers = this.NCTCGuideTransfers(quests, index, line);
      if NotEquals(transfers, "") { transferCount += 1; };
      this.NCTCGuideAddStopRow(ordinal, stopName, transfers, colorIndex, Equals(ordinal, selectedCount));
    };
    index += 1;
  };

  if ordinal > 0 {
    this.nctcGuideRouteTitle.SetText("LINE " + ToString(this.nctcGuideSelectedLine));
    this.nctcGuideRouteMeta.SetText(firstName + "  //  " + lastName + "  //  " + ToString(ordinal) + " STOPS  //  " + ToString(transferCount) + " TRANSFERS");
  } else {
    this.nctcGuideRouteTitle.SetText("LINE " + ToString(this.nctcGuideSelectedLine) + " OFFLINE");
    this.nctcGuideRouteMeta.SetText("No stops are published for this service.");
  };
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideFallbackName(quests: ref<QuestsSystem>, prefix: String) -> String {
  let locKey: Int32 = quests.GetFact(StringToName(prefix + "loc_key"));
  if locKey > 0 { return GetLocalizedText("LocKey#" + ToString(locKey)); };
  return "NCTC STOP";
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideTransfers(quests: ref<QuestsSystem>, sourceIndex: Int32, sourceLine: Int32) -> String {
  let sourcePrefix: String = "nctc_external_stop_" + ToString(sourceIndex) + "_";
  let sourceLoc: Int32 = quests.GetFact(StringToName(sourcePrefix + "loc_key"));
  let sourceX: Int32 = quests.GetFact(StringToName(sourcePrefix + "x"));
  let sourceY: Int32 = quests.GetFact(StringToName(sourcePrefix + "y"));
  let sourceZ: Int32 = quests.GetFact(StringToName(sourcePrefix + "z"));
  let count: Int32 = quests.GetFact(n"nctc_external_network_stop_count");
  let index: Int32 = 0;
  let prefix: String;
  let line: Int32;
  let loc: Int32;
  let same: Bool;
  let seen: String = "|";
  let result: String = "";

  while index < count {
    if NotEquals(index, sourceIndex) {
      prefix = "nctc_external_stop_" + ToString(index) + "_";
      line = quests.GetFact(StringToName(prefix + "line"));
      if line > 0 && line < 100 && NotEquals(line, sourceLine) {
        loc = quests.GetFact(StringToName(prefix + "loc_key"));
        same = sourceLoc > 0 && Equals(sourceLoc, loc);
        if !same && sourceLoc <= 0 && loc <= 0 {
          same = Abs(quests.GetFact(StringToName(prefix + "x")) - sourceX) <= 5000
            && Abs(quests.GetFact(StringToName(prefix + "y")) - sourceY) <= 5000
            && Abs(quests.GetFact(StringToName(prefix + "z")) - sourceZ) <= 5000;
        };
        if same && !StrContains(seen, "|" + ToString(line) + "|") {
          seen += ToString(line) + "|";
          result += Equals(result, "") ? "CHANGE L" + ToString(line) : " / L" + ToString(line);
        };
      };
    };
    index += 1;
  };
  return result;
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideAddStopRow(ordinal: Int32, stopName: String, transfers: String, colorIndex: Int32, isLast: Bool) -> Void {
  let row: ref<inkCanvas> = new inkCanvas();
  let marker: ref<inkRectangle> = new inkRectangle();
  let connector: ref<inkRectangle> = new inkRectangle();
  let number: ref<inkText>;
  let label: ref<inkText>;
  let change: ref<inkText>;
  let color: HDRColor = this.NCTCGuideLineColor(colorIndex);

  row.SetSize(Vector2(540.00, 32.00));
  row.SetInteractive(false);
  row.Reparent(this.nctcGuideRoutePanel);

  connector.SetMargin(inkMargin(13.00, 18.00, 0.00, 0.00));
  connector.SetSize(Vector2(3.00, 20.00));
  connector.SetTintColor(color);
  connector.SetOpacity(0.55);
  connector.SetVisible(!isLast);
  connector.Reparent(row);

  marker.SetMargin(inkMargin(8.00, 8.00, 0.00, 0.00));
  marker.SetSize(Vector2(13.00, 13.00));
  marker.SetTintColor(color);
  marker.Reparent(row);

  number = this.NCTCGuideText(row, ordinal < 10 ? "0" + ToString(ordinal) : ToString(ordinal), 18, 34.00, 0.00, 42.00, 30.00, HDRColor(0.42, 0.55, 0.60, 1.00));
  label = this.NCTCGuideText(row, stopName, 22, 80.00, 0.00, 305.00, 30.00, HDRColor(0.92, 0.96, 0.98, 1.00));
  label.SetLetterCase(textLetterCase.UpperCase);

  if NotEquals(transfers, "") {
    change = this.NCTCGuideText(row, transfers, 15, 385.00, 0.00, 150.00, 30.00, HDRColor(1.65, 0.30, 0.18, 1.00));
    change.SetHorizontalAlignment(textHorizontalAlignment.Right);
    change.SetContentHAlign(inkEHorizontalAlign.Right);
  };
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideLineColor(index: Int32) -> HDRColor {
  switch index {
    case 0: return HDRColor(0.20, 0.78, 1.50, 1.00);
    case 1: return HDRColor(2.00, 0.20, 0.18, 1.00);
    case 2: return HDRColor(1.85, 0.66, 0.12, 1.00);
    case 3: return HDRColor(1.55, 1.20, 0.12, 1.00);
    case 4: return HDRColor(0.35, 1.40, 0.62, 1.00);
    case 5: return HDRColor(0.95, 0.45, 1.55, 1.00);
    case 6: return HDRColor(0.35, 1.35, 1.20, 1.00);
    default: return HDRColor(0.32, 1.25, 1.55, 1.00);
  };
}
