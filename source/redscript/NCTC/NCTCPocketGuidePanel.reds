module NCTC

// Keep a strong reference to the panel controller-side. The live Ink tree also
// owns the widget after Reparent(), but retaining it removes weak-reference
// lifetime from the diagnostic path entirely.
@addField(WorldMapMenuGameController)
let nctcGuidePanelOwner: ref<inkCanvas>;

// Builds only the native Pocket Guide panel. The main map button is provided
// by NCTCPocketGuideProbe, whose Metro-style plumbing is already validated in-game.
@addMethod(WorldMapMenuGameController)
private final func NCTCCreatePocketGuidePanelOnly() -> Void {
  let root: ref<inkCompoundWidget>;
  let parent: ref<inkCompoundWidget>;
  let background: ref<inkRectangle>;
  let cyanRail: ref<inkRectangle>;
  let redRail: ref<inkRectangle>;
  let divider: ref<inkRectangle>;
  let lineHeader: ref<inkText>;
  let brand: ref<inkText>;
  let subtitle: ref<inkText>;
  let footer: ref<inkText>;

  LogChannel(n"DEBUG", "[NCTC] PocketGuide panel: create requested");

  if IsDefined(this.nctcGuidePanel) {
    LogChannel(n"DEBUG", "[NCTC] PocketGuide panel: already exists");
    return;
  };

  // Reuse the exact Content widget that already hosts the visible/clickable
  // NCTC button. Only resolve the path again as a defensive fallback.
  parent = this.nctcGuideHost;
  if IsDefined(parent) {
    LogChannel(n"DEBUG", "[NCTC] PocketGuide panel: using retained Content host");
  } else {
    LogChannel(n"DEBUG", "[NCTC] PocketGuide panel: retained host missing, resolving fallback");
    root = this.GetRootCompoundWidget();
    if !IsDefined(root) {
      LogChannel(n"DEBUG", "[NCTC] PocketGuide panel: root missing");
      return;
    };

    parent = root.GetWidgetByPathName(n"Content") as inkCompoundWidget;
    if !IsDefined(parent) {
      LogChannel(n"DEBUG", "[NCTC] PocketGuide panel: Content missing");
      return;
    };
    this.nctcGuideHost = parent;
  };

  // Create and attach the panel FIRST. Keep both a strong owner and the public
  // weak reference used by the rest of the Pocket Guide code.
  this.nctcGuidePanelOwner = new inkCanvas();
  this.nctcGuidePanel = this.nctcGuidePanelOwner;
  this.nctcGuidePanel.SetName(n"NCTCPocketGuidePanel");
  this.nctcGuidePanel.SetAnchor(inkEAnchor.TopRight);
  this.nctcGuidePanel.SetAnchorPoint(1.00, 0.00);
  this.nctcGuidePanel.SetMargin(inkMargin(0.00, 92.00, 55.00, 0.00));
  this.nctcGuidePanel.SetSize(Vector2(900.00, 820.00));
  this.nctcGuidePanel.SetInteractive(true);
  this.nctcGuidePanel.SetVisible(false);
  this.nctcGuidePanel.Reparent(parent);
  LogChannel(n"DEBUG", "[NCTC] PocketGuide panel: root panel reparented");

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

  LogChannel(n"DEBUG", "[NCTC] PocketGuide panel: content complete");
}
