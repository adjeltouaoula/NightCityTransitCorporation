module NCTC

// World-space prototype. Like the NCART screens, this listens for route
// changes and reads the vehicle owner; it does not require a seated player.
public class NCTCBusDisplayController extends inkGameController {
  private let bus: wref<VehicleObject>;
  private let quests: wref<QuestsSystem>;
  private let routeListener: Uint32;
  private let requestedListener: Uint32;
  private let lineText: ref<inkText>;
  private let headerText: ref<inkText>;
  private let stopText: ref<inkText>;
  private let lineOnly: Bool;

  protected cb func OnInitialize() -> Bool {
    let root: ref<inkCompoundWidget> = this.GetRootWidget() as inkCompoundWidget;
    this.bus = this.GetOwnerEntity() as VehicleObject;
    if !IsDefined(root) || !IsDefined(this.bus) || !this.bus.RecordHasTag(n"NCTCServiceBus") {
      if IsDefined(root) { root.SetVisible(false); };
      return false;
    };
    this.quests = GameInstance.GetQuestsSystem(this.bus.GetGame());
    if !IsDefined(this.quests) { root.SetVisible(false); return false; };
    root.RemoveAllChildren();
    this.lineOnly = Equals(root.GetName(), n"NCTCBusLineDisplay");
    if this.lineOnly {
      this.lineText = this.CreateLabel(root, 104, 0.00, 128.00);
    } else {
      this.headerText = this.CreateLabel(root, 30, 4.00, 42.00);
      this.stopText = this.CreateLabel(root, 58, 39.00, 85.00);
    };
    this.routeListener = this.quests.RegisterListener(n"nctc_display_revision", this, n"OnRouteChanged");
    this.requestedListener = this.quests.RegisterListener(n"nctc_display_stop_requested", this, n"OnRouteChanged");
    this.Refresh();
    return true;
  }

  private func CreateLabel(root: ref<inkCompoundWidget>, size: Int32, top: Float, height: Float) -> ref<inkText> {
    let label: ref<inkText> = new inkText();
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetFontStyle(n"Semi-Bold");
    label.SetFontSize(size);
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetMargin(new inkMargin(12.00, top, 12.00, 0.00));
    label.SetSize(new Vector2(1000.00, height));
    label.SetHorizontalAlignment(textHorizontalAlignment.Center);
    label.SetVerticalAlignment(textVerticalAlignment.Center);
    label.SetContentHAlign(inkEHorizontalAlign.Center);
    label.SetTintColor(new HDRColor(0.73, 0.14, 0.14, 1.00));
    label.Reparent(root);
    return label;
  }

  protected cb func OnRouteChanged(value: Int32) -> Bool {
    this.Refresh();
    return true;
  }

  private func Refresh() -> Void {
    let line: Int32 = this.quests.GetFact(n"nctc_display_line");
    let stopId: Int32 = this.quests.GetFact(n"nctc_display_next_stop_id");
    let count: Int32 = this.quests.GetFact(n"nctc_external_network_stop_count");
    let index: Int32 = 0;
    let ordinal: Int32 = 0;
    let prefix: String;
    let name: String = "—";
    let markers: ref<NCTCMapMarkerSystem>;
    while index < count {
      prefix = "nctc_external_stop_" + ToString(index) + "_";
      if Equals(this.quests.GetFact(StringToName(prefix + "line")), line) {
        ordinal += 1;
        if Equals(this.quests.GetFact(StringToName(prefix + "id")), stopId) {
          markers = GameInstance.GetScriptableSystemsContainer(this.bus.GetGame()).Get(NameOf<NCTCMapMarkerSystem>()) as NCTCMapMarkerSystem;
          if IsDefined(markers) { name = markers.GetSurveyStopName(line, ordinal); };
          break;
        };
      };
      index += 1;
    };
    if this.lineOnly {
      this.lineText.SetText(line > 0 ? ToString(line) : "—");
    } else {
      this.headerText.SetText("NEXT  >  STOP");
      this.stopText.SetText(name);
      this.stopText.SetTintColor(Equals(this.quests.GetFact(n"nctc_display_stop_requested"), 1)
        ? new HDRColor(1.00, 0.55, 0.10, 1.00) : new HDRColor(0.73, 0.14, 0.14, 1.00));
    };
  }

  protected cb func OnUninitialize() -> Bool {
    if IsDefined(this.quests) {
      this.quests.UnregisterListener(n"nctc_display_revision", this.routeListener);
      this.quests.UnregisterListener(n"nctc_display_stop_requested", this.requestedListener);
    };
    return true;
  }
}
