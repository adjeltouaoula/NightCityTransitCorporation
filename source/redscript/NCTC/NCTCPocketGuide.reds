module NCTC

import Codeware.UI.*

// NCTC native Pocket Guide.
// This deliberately follows the same world-map / HubLinkButton plumbing used
// by Metro Pocket Guide, while reading only NCTC's published network facts.
public class NCTCGuideButton extends HubLinkButton {
  public static func Create() -> ref<NCTCGuideButton> {
    let self = new NCTCGuideButton();
    self.CreateInstance();
    return self;
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_icon.SetMargin(0.00, 30.00, 0.00, 6.00);
    this.m_icon.SetSize(Vector2(70.00, 52.00));
    this.m_icon.SetAtlasResource(r"base\gameplay\gui\common\icons\mappin_icons.inkatlas");
    this.m_icon.SetTexturePart(n"fast_travel");
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
    this.SetIcon(n"");
    this.m_root.SetAnchorPoint(Vector2(0.00, 0.00));
    this.m_root.SetScale(Vector2(0.42, 0.42));
    this.m_label.SetFontSize(44);
    this.m_label.SetMargin(inkMargin(22.00, -5.00, 0.00, 0.00));
  }

  public func GetLine() -> Int32 {
    return this.m_line;
  }

  public func SetGuidePosition(y: Float) -> Void {
    this.m_root.SetMargin(inkMargin(20.00, y, 0.00, 0.00));
  }

  public func SetSelected(selected: Bool) -> Void {
    if selected {
      this.m_root.SetOpacity(1.00);
    } else {
      this.m_root.SetOpacity(0.55);
    };
  }
}

@addField(WorldMapMenuGameController)
let nctcGuideButtonContainer: wref<inkCompoundWidget>;

@addField(WorldMapMenuGameController)
let nctcGuideButton: wref<NCTCGuideButton>;

@addField(WorldMapMenuGameController)
let nctcGuidePanel: wref<inkCanvas>;

@addField(WorldMapMenuGameController)
let nctcGuideLinePanel: wref<inkCanvas>;

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

// Use the already-proven NCTC world-map wrapper pattern: preserve and return
// the wrapped result. This composes with NCTCMapMarkers and Metro Pocket Guide.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  this.NCTCCreatePocketGuide();
  return result;
}

@addMethod(WorldMapMenuGameController)
private final func NCTCCreatePocketGuide() -> Void {
  let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  let parent: ref<inkCompoundWidget>;
  let background: ref<inkRectangle>;
  let cyanRail: ref<inkRectangle>;
  let redRail: ref<inkRectangle>;
  let divider: ref<inkRectangle>;
  let lineHeader: ref<inkText>;
  let brand: ref<inkText>;
  let subtitle: ref<inkText>;
  let footer: ref<inkText>;

  if !IsDefined(root) { return; };
  parent = root.GetWidgetByPathName(n"Content") as inkCompoundWidget;
  if !IsDefined(parent) { return; };

  // Same parent/anchor strategy used by Metro Pocket Guide controls. Keep the
  // NCTC entry one row above it so both mods remain usable side by side.
  this.nctcGuideButtonContainer = new inkCanvas();
  this.nctcGuideButtonContainer.SetName(n"NCTCGuideButtonContainer");
  this.nctcGuideButtonContainer.SetAnchor(inkEAnchor.BottomCenter);
  this.nctcGuideButtonContainer.SetAnchorPoint(0.50, 1.00);
  this.nctcGuideButtonContainer.SetFitToContent(true);
  this.nctcGuideButtonContainer.SetInteractive(false);
  this.nctcGuideButtonContainer.SetMargin(inkMargin(0.00, 0.00, 0.00, 330.00));
  this.nctcGuideButtonContainer.Reparent(parent);

  this.nctcGuideButton = NCTCGuideButton.Create();
  this.nctcGuideButton.SetName(n"NCTCGuideToggle");
  this.nctcGuideButton.SetText("NCTC BUS NETWORK");
  this.nctcGuideButton.RegisterToCallback(n"OnClick", this, n"OnNCTCGuideToggle");
  this.nctcGuideButton.Reparent(this.nctcGuideButtonContainer);

  this.nctcGuidePanel = new inkCanvas();
  this.nctcGuidePanel.SetName(n"NCTCPocketGuidePanel");
  this.nctcGuidePanel.SetAnchor(inkEAnchor.TopRight);
  this.nctcGuidePanel.SetAnchorPoint(1.00, 0.00);
  this.nctcGuidePanel.SetMargin(inkMargin(0.00, 92.00, 55.00, 0.00));
  this.nctcGuidePanel.SetSize(Vector2(900.00, 820.00));
  this.nctcGuidePanel.SetInteractive(true);
  this.nctcGuidePanel.SetVisible(false);
  this.nctcGuidePanel.Reparent(parent);

  background = new inkRectangle();
  background.SetName(n"NCTCGuideBackground");
  background.SetSize(Vector2(900.00, 820.00));
  background.SetTintColor(new HDRColor(0.008, 0.012, 0.018, 0.965));
  background.Reparent(this.nctcGuidePanel);

  cyanRail = new inkRectangle();
  cyanRail.SetSize(Vector2(900.00, 5.00));
  cyanRail.SetTintColor(new HDRColor(0.10, 1.20, 1.55, 1.00));
  cyanRail.Reparent(this.nctcGuidePanel);

  redRail = new inkRectangle();
  redRail.SetMargin(inkMargin(0.00, 5.00, 0.00, 0.00));
  redRail.SetSize(Vector2(210.00, 3.00));
  redRail.SetTintColor(new HDRColor(2.10, 0.14, 0.12, 1.00));
  redRail.Reparent(this.nctcGuidePanel);

  brand = this.NCTCGuideText(this.nctcGuidePanel, "NIGHT CITY TRANSIT CORPORATION", 38, 38.00, 26.00, 790.00, 52.00, new HDRColor(0.26, 1.15, 1.45, 1.00));
  brand.SetFontStyle(n"Semi-Bold");

  subtitle = this.NCTCGuideText(this.nctcGuidePanel, "BUS NETWORK // POCKET GUIDE", 22, 40.00, 78.00, 700.00, 34.00, new HDRColor(1.65, 0.20, 0.18, 1.00));
  subtitle.SetLetterCase(textLetterCase.UpperCase);

  this.nctcGuideStatus = this.NCTCGuideText(this.nctcGuidePanel, "NETWORK STANDBY", 18, 40.00, 116.00, 760.00, 30.00, new HDRColor(0.52, 0.62, 0.67, 1.00));

  lineHeader = this.NCTCGuideText(this.nctcGuidePanel, "LINES", 20, 38.00, 170.00, 190.00, 34.00, new HDRColor(0.30, 1.05, 1.28, 1.00));
  lineHeader.SetLetterCase(textLetterCase.UpperCase);

  divider = new inkRectangle();
  divider.SetMargin(inkMargin(245.00, 168.00, 0.00, 0.00));
  divider.SetSize(Vector2(2.00, 574.00));
  divider.SetTintColor(new HDRColor(0.10, 0.30, 0.36, 0.80));
  divider.Reparent(this.nctcGuidePanel);

  this.nctcGuideLinePanel = new inkCanvas();
  this.nctcGuideLinePanel.SetName(n"NCTCGuideLines");
  this.nctcGuideLinePanel.SetMargin(inkMargin(20.00, 205.00, 0.00, 0.00));
  this.nctcGuideLinePanel.SetSize(Vector2(220.00, 510.00));
  this.nctcGuideLinePanel.Reparent(this.nctcGuidePanel);

  this.nctcGuideAccent = new inkRectangle();
  this.nctcGuideAccent.SetMargin(inkMargin(277.00, 172.00, 0.00, 0.00));
  this.nctcGuideAccent.SetSize(Vector2(8.00, 66.00));
  this.nctcGuideAccent.SetTintColor(new HDRColor(1.75, 0.22, 0.16, 1.00));
  this.nctcGuideAccent.Reparent(this.nctcGuidePanel);

  this.nctcGuideRouteTitle = this.NCTCGuideText(this.nctcGuidePanel, "SELECT A LINE", 34, 302.00, 169.00, 545.00, 48.00, new HDRColor(0.92, 0.96, 0.98, 1.00));
  this.nctcGuideRouteTitle.SetFontStyle(n"Semi-Bold");

  this.nctcGuideRouteMeta = this.NCTCGuideText(this.nctcGuidePanel, "--", 18, 304.00, 215.00, 545.00, 34.00, new HDRColor(0.48, 0.59, 0.65, 1.00));

  this.nctcGuideRoutePanel = new inkVerticalPanel();
  this.nctcGuideRoutePanel.SetName(n"NCTCGuideRoute");
  this.nctcGuideRoutePanel.SetMargin(inkMargin(294.00, 262.00, 0.00, 0.00));
  this.nctcGuideRoutePanel.SetSize(Vector2(555.00, 475.00));
  this.nctcGuideRoutePanel.SetFitToContent(true);
  this.nctcGuideRoutePanel.Reparent(this.nctcGuidePanel);

  footer = this.NCTCGuideText(this.nctcGuidePanel, "NCTC // MOVE NIGHT CITY", 17, 38.00, 778.00, 790.00, 26.00, new HDRColor(0.28, 0.50, 0.57, 1.00));
  footer.SetLetterCase(textLetterCase.UpperCase);
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideText(parent: ref<inkCompoundWidget>, value: String, size: Int32, x: Float, y: Float, width: Float, height: Float, color: HDRColor) -> ref<inkText> {
  let text: ref<inkText> = new inkText();
  text.SetText(value);
  text.SetFontFamily("base\gameplay\gui\fonts\raj\raj.inkfontfamily");
  text.SetFontStyle(n"Medium");
  text.SetFontSize(size);
  text.SetLetterCase(textLetterCase.OriginalCase);
  text.SetMargin(inkMargin(x, y, 0.00, 0.00));
  text.SetSize(Vector2(width, height));
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
  if this.nctcGuideVisible {
    this.nctcGuideButton.SetText("CLOSE NCTC NETWORK");
    this.NCTCGuideReload();
  } else {
    this.nctcGuideButton.SetText("NCTC BUS NETWORK");
  };
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
  let y: Float = 0.00;

  this.nctcGuideLinePanel.RemoveAllChildren();
  ArrayClear(this.nctcGuideLineButtons);
  this.nctcGuideRoutePanel.RemoveAllChildren();

  if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_external_network_ready"), 1) {
    this.nctcGuideStatus.SetText("NETWORK OFFLINE // LOAD A SAVE");
    this.nctcGuideRouteTitle.SetText("NCTC DATA UNAVAILABLE");
    this.nctcGuideRouteMeta.SetText("Transit runtime has not published the network.");
    return;
  };

  count = quests.GetFact(n"nctc_external_network_stop_count");
  while index < count {
    line = quests.GetFact(StringToName("nctc_external_stop_" + ToString(index) + "_line"));
    if line > 0 && line < 100 && !ArrayContains(lines, line) {
      ArrayPush(lines, line);
    };
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
    this.nctcGuideRouteMeta.SetText("No passenger services found in the active network.");
    return;
  };

  if !ArrayContains(lines, this.nctcGuideSelectedLine) {
    this.nctcGuideSelectedLine = lines[0];
  };

  for line in lines {
    button = NCTCGuideLineButton.Create(line);
    button.SetName(StringToName("NCTCGuideLine" + ToString(line)));
    button.SetText("LINE " + ToString(line));
    button.SetGuidePosition(y);
    button.SetSelected(Equals(line, this.nctcGuideSelectedLine));
    button.RegisterToCallback(n"OnClick", this, n"OnNCTCGuideLine");
    button.Reparent(this.nctcGuideLinePanel);
    ArrayPush(this.nctcGuideLineButtons, button);
    y += 58.00;
  };

  this.nctcGuideStatus.SetText("LIVE NETWORK // REV " + ToString(quests.GetFact(n"nctc_external_network_revision")));
  this.NCTCGuideRefreshLine();
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideRefreshLine() -> Void {
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetPlayerControlledObject().GetGame());
  let indices: array<Int32>;
  let button: ref<NCTCGuideLineButton>;
  let count: Int32;
  let index: Int32 = 0;
  let scan: Int32;
  let temp: Int32;
  let leftSequence: Int32;
  let rightSequence: Int32;
  let stopIndex: Int32;
  let prefix: String;
  let stopName: String;
  let firstName: String = "";
  let lastName: String = "";
  let transfers: String;
  let transferCount: Int32 = 0;
  let colorIndex: Int32;
  let ordinal: Int32 = 0;

  if !IsDefined(quests) { return; };
  this.nctcGuideRoutePanel.RemoveAllChildren();

  for button in this.nctcGuideLineButtons {
    button.SetSelected(Equals(button.GetLine(), this.nctcGuideSelectedLine));
  };

  colorIndex = quests.GetFact(StringToName("nctc_external_line_" + ToString(this.nctcGuideSelectedLine) + "_color"));
  this.nctcGuideAccent.SetTintColor(NCTCLineColor(colorIndex));

  count = quests.GetFact(n"nctc_external_network_stop_count");
  while index < count {
    if Equals(quests.GetFact(StringToName("nctc_external_stop_" + ToString(index) + "_line")), this.nctcGuideSelectedLine) {
      ArrayPush(indices, index);
    };
    index += 1;
  };

  index = 0;
  while index < ArraySize(indices) {
    scan = index + 1;
    while scan < ArraySize(indices) {
      leftSequence = quests.GetFact(StringToName("nctc_external_stop_" + ToString(indices[index]) + "_sequence"));
      rightSequence = quests.GetFact(StringToName("nctc_external_stop_" + ToString(indices[scan]) + "_sequence"));
      if rightSequence < leftSequence {
        temp = indices[index];
        indices[index] = indices[scan];
        indices[scan] = temp;
      };
      scan += 1;
    };
    index += 1;
  };

  index = 0;
  while index < ArraySize(indices) {
    stopIndex = indices[index];
    prefix = "nctc_external_stop_" + ToString(stopIndex) + "_";
    ordinal += 1;
    stopName = this.NCTCGuideStopName(quests, prefix);
    if Equals(firstName, "") { firstName = stopName; };
    lastName = stopName;
    transfers = this.NCTCGuideTransfers(quests, stopIndex, this.nctcGuideSelectedLine);
    if NotEquals(transfers, "") { transferCount += 1; };
    this.NCTCGuideAddStopRow(ordinal, stopName, transfers, colorIndex, Equals(index, ArraySize(indices) - 1));
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
private final func NCTCGuideStopName(quests: ref<QuestsSystem>, prefix: String) -> String {
  let locKey: Int32 = quests.GetFact(StringToName(prefix + "loc_key"));
  let stopId: Int32 = quests.GetFact(StringToName(prefix + "id"));
  let value: String;
  if locKey > 0 {
    value = GetLocalizedText("LocKey#" + ToString(locKey));
    if NotEquals(value, "") && NotEquals(value, "LocKey#" + ToString(locKey)) {
      return value;
    };
  };
  return "NCTC STOP " + ToString(stopId);
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
          if Equals(result, "") {
            result = "CHANGE L" + ToString(line);
          } else {
            result += " / L" + ToString(line);
          };
        };
      };
    };
    index += 1;
  };
  return result;
}

@addMethod(WorldMapMenuGameController)
private final func NCTCGuideAddStopRow(sequence: Int32, stopName: String, transfers: String, colorIndex: Int32, isLast: Bool) -> Void {
  let row: ref<inkCanvas> = new inkCanvas();
  let dot: ref<inkRectangle> = new inkRectangle();
  let connector: ref<inkRectangle>;
  let number: ref<inkText>;
  let name: ref<inkText>;
  let transfer: ref<inkText>;

  row.SetSize(Vector2(550.00, 60.00));
  row.SetInteractive(false);
  row.Reparent(this.nctcGuideRoutePanel);

  dot.SetMargin(inkMargin(9.00, 9.00, 0.00, 0.00));
  dot.SetSize(Vector2(14.00, 14.00));
  dot.SetTintColor(NCTCLineColor(colorIndex));
  dot.Reparent(row);

  if !isLast {
    connector = new inkRectangle();
    connector.SetMargin(inkMargin(14.00, 23.00, 0.00, 0.00));
    connector.SetSize(Vector2(3.00, 42.00));
    connector.SetTintColor(NCTCLineColor(colorIndex));
    connector.SetOpacity(0.72);
    connector.Reparent(row);
  };

  number = this.NCTCGuideText(row, ToString(sequence), 17, 34.00, 0.00, 38.00, 31.00, new HDRColor(0.42, 0.58, 0.64, 1.00));
  number.SetFontStyle(n"Semi-Bold");

  name = this.NCTCGuideText(row, stopName, 22, 78.00, 0.00, 455.00, 32.00, new HDRColor(0.90, 0.95, 0.98, 1.00));
  name.SetFontStyle(n"Medium");

  if NotEquals(transfers, "") {
    transfer = this.NCTCGuideText(row, transfers, 15, 78.00, 29.00, 455.00, 24.00, new HDRColor(1.55, 0.24, 0.19, 1.00));
    transfer.SetLetterCase(textLetterCase.UpperCase);
  };
}
