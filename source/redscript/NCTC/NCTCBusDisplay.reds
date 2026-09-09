module NCTC

// Route signs belong to the service, not to the driver's dashboard lifecycle.
// Preserve the existing implementation (including EVS), then restore only our
// six named components. This runs on lifecycle changes, never on a timer.
@wrapMethod(VehicleObject)
private final func SetInteriorUIEnabled(enabled: Bool) -> Void {
  let names: array<CName>;
  let widget: ref<worlduiWidgetComponent>;
  wrappedMethod(enabled);
  names = [n"nctc_interior_route_display", n"nctc_front_line_display", n"nctc_front_route_display", n"nctc_right_route_display", n"nctc_left_route_display", n"nctc_rear_line_display"];
  for name in names {
    widget = this.FindComponentByName(name) as worlduiWidgetComponent;
    if IsDefined(widget) && !widget.IsEnabled() {
      widget.Toggle(true);
    };
  };
}

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
  private let probe: Bool;
  private let displayedStopName: String;
  private let hasDisplayedStop: Bool;

  protected cb func OnInitialize() -> Bool {
    let background: ref<inkRectangle>;
    let arrow: ref<inkRectangle>;
    let arrowRow: Int32;
    let arrowWidth: Float;
    let headerStop: ref<inkText>;
    let root: ref<inkCompoundWidget> = this.GetRootWidget() as inkCompoundWidget;
    this.bus = this.GetOwnerEntity() as VehicleObject;
    // This widget is embedded only in the dedicated NCTC entity template.
    if !IsDefined(root) || !IsDefined(this.bus) {
      if IsDefined(root) { root.SetVisible(false); };
      return false;
    };
    this.quests = GameInstance.GetQuestsSystem(this.bus.GetGame());
    if !IsDefined(this.quests) { root.SetVisible(false); return false; };
    root.RemoveAllChildren();
    this.lineOnly = Equals(root.GetName(), n"NCTCBusLineDisplay") || Equals(root.GetName(), n"NCTCBusRearLineDisplay");
    this.probe = Equals(root.GetName(), n"NCTCBusProbeDisplay");
    if this.probe {
      this.CreateVisualProbe(root);
    } else { if this.lineOnly {
      // Font size is clamped to 200 by INK. Use a proportionate canvas instead.
      this.lineText = this.CreateLabel(root, 200, 0.00, Equals(root.GetName(), n"NCTCBusRearLineDisplay") ? 260.00 : 240.00);
      this.lineText.SetSize(new Vector2(320.00, Equals(root.GetName(), n"NCTCBusRearLineDisplay") ? 260.00 : 240.00));
      this.lineText.SetMargin(new inkMargin(0.00, 0.00, 0.00, 0.00));
      this.lineText.SetTintColor(new HDRColor(2.92, 0.56, 0.56, 1.00));
    } else {
      background = new inkRectangle();
      background.SetSize(new Vector2(1024.00, 116.00));
      background.SetTintColor(new HDRColor(0.005, 0.005, 0.005, 1.00));
      background.Reparent(root);
      this.headerText = this.CreateLabel(root, 44, 0.00, 116.00);
      this.headerText.SetSize(new Vector2(112.00, 116.00));
      this.headerText.SetMargin(new inkMargin(20.00, 0.00, 0.00, 0.00));
      this.headerText.SetText("NEXT");
      this.headerText.SetTintColor(new HDRColor(2.92, 0.56, 0.56, 1.00));
      // Rasterize a filled right-pointing triangle at canvas resolution.
      // Bare inkShape vertexList did not render in the world-widget target.
      // These static rows use the same verified primitive as the background.
      arrowRow = 0;
      while arrowRow < 28 {
        arrowWidth = 26.00 * (1.00 - AbsF((Cast<Float>(arrowRow) + 0.50 - 14.00) / 14.00));
        arrow = new inkRectangle();
        arrow.SetName(n"NCTCNextStopTriangleRow");
        arrow.SetSize(new Vector2(arrowWidth, 1.00));
        arrow.SetMargin(new inkMargin(132.00, 44.00 + Cast<Float>(arrowRow), 0.00, 0.00));
        arrow.SetTintColor(new HDRColor(2.92, 0.56, 0.56, 1.00));
        arrow.Reparent(root);
        arrowRow += 1;
      };
      headerStop = this.CreateLabel(root, 44, 0.00, 116.00);
      headerStop.SetSize(new Vector2(120.00, 116.00));
      headerStop.SetMargin(new inkMargin(158.00, 0.00, 0.00, 0.00));
      headerStop.SetText("STOP");
      headerStop.SetTintColor(new HDRColor(2.92, 0.56, 0.56, 1.00));
      this.stopText = this.CreateLabel(root, 100, 0.00, 116.00);
      this.stopText.SetMargin(new inkMargin(312.00, 0.00, 12.00, 0.00));
      this.stopText.SetSize(new Vector2(700.00, 116.00));
      this.stopText.SetWrapping(false);
      this.stopText.SetOverflowPolicy(textOverflowPolicy.AutoScroll);
      // Native inkText defaults are speed 0.2 / delay 30 (engine units).
      this.stopText.scrollTextSpeed = 2.50;
      this.stopText.scrollDelay = Cast<Uint16>(45);
    }; };
    this.routeListener = this.quests.RegisterListener(n"nctc_display_revision", this, n"OnRouteChanged");
    this.requestedListener = this.quests.RegisterListener(n"nctc_display_stop_requested", this, n"OnRouteChanged");
    this.Refresh();
    return true;
  }

  // Same validated probe surface, now displaying the existing route facts.
  private func CreateVisualProbe(root: ref<inkCompoundWidget>) -> Void {
    let background: ref<inkRectangle> = new inkRectangle();
    root.RemoveAllChildren();
    root.SetSize(new Vector2(1024.00, 512.00));
    root.SetVisible(true);
    root.SetOpacity(1.00);
    background.SetName(n"NCTCProbeBackground");
    background.SetSize(new Vector2(1024.00, 512.00));
    background.SetTintColor(new HDRColor(1.00, 0.00, 1.00, 1.00));
    background.SetOpacity(1.00);
    background.SetVisible(true);
    background.Reparent(root);
    // The Probe resource is now 1024x512 from creation, matching the mesh.
    this.lineText = this.CreateLabel(root, 100, 20.00, 160.00);
    this.lineText.SetName(n"NCTCProbeLine");
    this.headerText = this.CreateLabel(root, 40, 182.00, 70.00);
    this.headerText.SetName(n"NCTCProbeHeader");
    this.stopText = this.CreateLabel(root, 54, 254.00, 220.00);
    this.stopText.SetName(n"NCTCProbeStop");
    for label in [this.lineText, this.headerText, this.stopText] {
      label.SetFitToContent(false);
      label.SetContentVAlign(inkEVerticalAlign.Center);
      label.SetTintColor(new HDRColor(1.00, 1.00, 1.00, 1.00));
    };
  }

  private func CreateLabel(root: ref<inkCompoundWidget>, size: Int32, top: Float, height: Float) -> ref<inkText> {
    let label: ref<inkText> = new inkText();
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetFontStyle(n"Semi-Bold");
    label.SetFontSize(size);
    label.SetLetterCase(textLetterCase.UpperCase);
    label.SetMargin(new inkMargin(12.00, top, 12.00, 0.00));
    label.SetSize(new Vector2(1000.00, height));
    label.SetFitToContent(false);
    label.SetHorizontalAlignment(textHorizontalAlignment.Center);
    label.SetVerticalAlignment(textVerticalAlignment.Center);
    label.SetContentHAlign(inkEHorizontalAlign.Center);
    label.SetContentVAlign(inkEVerticalAlign.Center);
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
    if this.lineOnly || this.probe {
      this.lineText.SetText(line > 0 ? ToString(line) : "—");
    };
    if !this.lineOnly {
      if this.probe && IsDefined(this.headerText) { this.headerText.SetText("NEXT STOP"); };
      // SetText can restart AutoScroll. Arrival/request notifications must not
      // reset an unchanged destination; tint updates remain independent.
      if !this.hasDisplayedStop || NotEquals(this.displayedStopName, name) {
        this.stopText.SetText(name);
        this.displayedStopName = name;
        this.hasDisplayedStop = true;
      };
      this.stopText.SetTintColor(Equals(this.quests.GetFact(n"nctc_display_stop_requested"), 1)
        ? new HDRColor(1.00, 0.55, 0.10, 1.00) : (this.probe ? new HDRColor(1.00, 1.00, 1.00, 1.00) : new HDRColor(2.92, 0.56, 0.56, 1.00)));
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
