module NCTC

// World-space prototype. Like the NCART screens, this listens for route
// changes and reads the vehicle owner; it does not require a seated player.
public class NCTCBusDisplayController extends inkGameController {
  private let bus: wref<VehicleObject>;
  private let quests: wref<QuestsSystem>;
  private let routeListener: Uint32;
  private let requestedListener: Uint32;
  private let lineText: ref<inkText>;
  private let stopText: ref<inkText>;

  protected cb func OnInitialize() -> Bool {
    let root: ref<inkCompoundWidget> = this.GetRootWidget() as inkCompoundWidget;
    this.bus = this.GetOwnerEntity() as VehicleObject;
    if !IsDefined(root) || !IsDefined(this.bus) { return false; };
    this.quests = GameInstance.GetQuestsSystem(this.bus.GetGame());
    root.RemoveAllChildren();
    this.lineText = this.CreateLabel(root, 52, 0.00);
    this.stopText = this.CreateLabel(root, 44, 62.00);
    this.routeListener = this.quests.RegisterListener(n"nctc_display_revision", this, n"OnRouteChanged");
    this.requestedListener = this.quests.RegisterListener(n"nctc_display_stop_requested", this, n"OnRouteChanged");
    this.Refresh();
    return true;
  }

  private func CreateLabel(root: ref<inkCompoundWidget>, size: Int32, top: Float) -> ref<inkText> {
    let label: ref<inkText> = new inkText();
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetFontStyle(n"Semi-Bold");
    label.SetFontSize(size);
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetMargin(new inkMargin(16.00, top, 0.00, 0.00));
    label.SetSize(new Vector2(992.00, 60.00));
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
    this.lineText.SetText("NCTC • " + ToString(line));
    this.stopText.SetText("NEXT STOP: " + name);
    this.stopText.SetTintColor(Equals(this.quests.GetFact(n"nctc_display_stop_requested"), 1)
      ? new HDRColor(1.00, 0.55, 0.10, 1.00) : new HDRColor(0.73, 0.14, 0.14, 1.00));
  }

  protected cb func OnUninitialize() -> Bool {
    if IsDefined(this.quests) {
      this.quests.UnregisterListener(n"nctc_display_revision", this.routeListener);
      this.quests.UnregisterListener(n"nctc_display_stop_requested", this.requestedListener);
    };
    return true;
  }
}
