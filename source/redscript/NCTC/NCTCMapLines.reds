module NCTC

public class NCTCMapLineVisibilityEvent extends Event {
  public let line: String;
  public let enabled: Bool;
}

@addField(WorldMapMenuGameController)
private let nctcMapModeButton: wref<inkText>;
@addField(WorldMapMenuGameController)
private let nctcMapModePanel: wref<inkVerticalPanel>;
@addField(WorldMapMenuGameController)
private let nctcMapModeActive: Bool;
@addField(WorldMapMenuGameController)
private let nctcMapLines: array<String>;
@addField(WorldMapMenuGameController)
private let nctcMapLineColors: array<Int32>;

@addMethod(WorldMapMenuGameController)
private final func CreateNCTCMapMode() -> Void {
  let root: ref<inkCompoundWidget> = this.GetRootCompoundWidget();
  let content: ref<inkCompoundWidget>;
  let buttonContainer: ref<inkCanvas>;
  let title: ref<inkText>;
  let row: ref<inkText>;
  let system: ref<NCTCMapMarkerSystem>;
  let index: Int32 = 0;
  if !IsDefined(root) || IsDefined(this.nctcMapModeButton) { return; };
  content = root.GetWidgetByPathName(n"Content") as inkCompoundWidget;
  if !IsDefined(content) { return; };

  buttonContainer = new inkCanvas();
  buttonContainer.SetName(n"NCTCMapModeButtonContainer");
  buttonContainer.SetAnchor(inkEAnchor.BottomCenter);
  buttonContainer.SetAnchorPoint(new Vector2(0.50, 1.00));
  buttonContainer.SetMargin(new inkMargin(460.00, 0.00, 0.00, 220.00));
  buttonContainer.SetFitToContent(true);
  buttonContainer.SetInteractive(false);
  buttonContainer.Reparent(content);

  this.nctcMapModeButton = new inkText();
  this.nctcMapModeButton.SetName(n"NCTCMapModeButton");
  this.nctcMapModeButton.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  this.nctcMapModeButton.SetFontSize(40);
  this.nctcMapModeButton.SetTintColor(new HDRColor(0.37, 0.96, 1.00, 1.00));
  this.nctcMapModeButton.SetInteractive(true);
  this.nctcMapModeButton.SetMargin(new inkMargin(24.00, 12.00, 24.00, 12.00));
  this.nctcMapModeButton.SetText("CARTE DES LIGNES NCTC");
  this.nctcMapModeButton.RegisterToCallback(n"OnRelease", this, n"OnNCTCMapModeButton");
  this.nctcMapModeButton.Reparent(buttonContainer);

  this.nctcMapModePanel = new inkVerticalPanel();
  this.nctcMapModePanel.SetName(n"NCTCMapModePanel");
  this.nctcMapModePanel.SetAnchor(inkEAnchor.CenterLeft);
  this.nctcMapModePanel.SetAnchorPoint(new Vector2(0.00, 0.50));
  this.nctcMapModePanel.SetMargin(new inkMargin(55.00, 0.00, 0.00, 0.00));
  this.nctcMapModePanel.SetFitToContent(true);
  this.nctcMapModePanel.SetVisible(false);
  this.nctcMapModePanel.Reparent(content);

  title = new inkText();
  title.SetName(n"NCTCMapModeTitle");
  title.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  title.SetFontSize(44);
  title.SetText("LIGNES NCTC");
  title.SetTintColor(new HDRColor(0.37, 0.96, 1.00, 1.00));
  title.SetMargin(new inkMargin(12.00, 0.00, 12.00, 16.00));
  title.Reparent(this.nctcMapModePanel);

  system = NCTCMapMarkerSystem.GetInstance(this.GetPlayerControlledObject().GetGame());
  if IsDefined(system) { system.GetMapLines(this.nctcMapLines, this.nctcMapLineColors); };
  while index < ArraySize(this.nctcMapLines) {
    row = new inkText();
    row.SetName(StringToName("NCTCMapLine_" + this.nctcMapLines[index]));
    row.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    row.SetFontSize(38);
    row.SetText("[X]  LIGNE " + this.nctcMapLines[index]);
    row.SetTintColor(NCTCLineColor(this.nctcMapLineColors[index]));
    row.SetInteractive(true);
    row.SetMargin(new inkMargin(12.00, 5.00, 12.00, 5.00));
    row.RegisterToCallback(n"OnRelease", this, n"OnNCTCMapLineToggle");
    row.Reparent(this.nctcMapModePanel);
    index += 1;
  };
}

@addMethod(WorldMapMenuGameController)
private final func SetNCTCMapMode(active: Bool) -> Void {
  let filterGroup: wref<MappinUIFilterGroup_Record>;
  this.nctcMapModeActive = active;
  this.nctcMapModePanel.SetVisible(active);
  this.nctcMapModeButton.SetText(active ? "FERMER LA CARTE NCTC" : "CARTE DES LIGNES NCTC");
  inkWidgetRef.SetVisible(this.m_filterSelector, !active);
  inkWidgetRef.SetVisible(this.m_customFilters, !active && Equals(this.GetQuickFilter(), gamedataWorldMapFilter.CustomFilter));
  if active {
    filterGroup = TweakDBInterface.GetMappinUIFilterGroupRecord(t"WorldMap.NCTCStopsFilterGroup");
    if IsDefined(filterGroup) { this.SetQuickFilterFromRecord(filterGroup); };
  };
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCMapModeButton(evt: ref<inkPointerEvent>) -> Bool {
  if !evt.IsAction(n"click") { return false; };
  this.PlaySound(n"Button", n"OnPress");
  this.SetNCTCMapMode(!this.nctcMapModeActive);
  return true;
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCMapLineToggle(evt: ref<inkPointerEvent>) -> Bool {
  let name: String;
  let line: String;
  let index: Int32;
  let text: ref<inkText>;
  let event: ref<NCTCMapLineVisibilityEvent>;
  if !evt.IsAction(n"click") { return false; };
  name = NameToString(evt.GetTarget().GetName());
  line = StrAfterFirst(name, "NCTCMapLine_");
  index = ArrayFindFirst(this.nctcMapLines, line);
  if index < 0 { return false; };
  text = evt.GetTarget() as inkText;
  if !IsDefined(text) { return false; };
  event = new NCTCMapLineVisibilityEvent();
  event.line = line;
  event.enabled = !StrBeginsWith(text.GetText(), "[X]");
  text.SetText((event.enabled ? "[X]  LIGNE " : "[ ]  LIGNE ") + line);
  GameInstance.GetUISystem(this.GetPlayerControlledObject().GetGame()).QueueEvent(event);
  this.PlaySound(n"Button", n"OnPress");
  return true;
}

@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  this.CreateNCTCMapMode();
  return result;
}

@wrapMethod(WorldMapMenuGameController)
protected cb func OnUninitialize() -> Bool {
  this.nctcMapModeActive = false;
  return wrappedMethod();
}

@addMethod(BaseWorldMapMappinController)
protected cb func OnNCTCMapLineVisibilityEvent(evt: ref<NCTCMapLineVisibilityEvent>) -> Bool {
  let data: ref<NCTCStopMappinData> = this.GetMappin().GetScriptData() as NCTCStopMappinData;
  let serviceIndex: Int32;
  let index: Int32 = 0;
  let visible: Bool = false;
  if !IsDefined(data) { return false; };
  serviceIndex = ArrayFindFirst(data.serviceLines, evt.line);
  if serviceIndex < 0 { return false; };
  data.serviceEnabled[serviceIndex] = evt.enabled;
  while index < ArraySize(data.serviceEnabled) {
    if data.serviceEnabled[index] { visible = true; };
    index += 1;
  };
  this.GetRootWidget().SetVisible(visible);
  this.GetRootWidget().SetInteractive(visible);
  return true;
}
