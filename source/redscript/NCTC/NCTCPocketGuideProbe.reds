module NCTC

import Codeware.UI.*

// Diagnostic/native bootstrap button copied from Metro Pocket Guide's proven
// HubLinkButton setup. This intentionally stays tiny so we can prove that the
// NCTC world-map hook reaches the live Ink tree before rebuilding the final UI.
public class NCTCGuideProbeButton extends HubLinkButton {
  public static func Create() -> ref<NCTCGuideProbeButton> {
    let self = new NCTCGuideProbeButton();
    self.CreateInstance();
    return self;
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_icon.SetMargin(0.0, 30.0, 0.0, 6.0);
    this.m_icon.SetSize(Vector2(82.0, 44.0));
    this.m_icon.SetTexturePart(n"ncart_logo_simple");
    this.m_icon.SetAtlasResource(r"base\\open_world\\metro\\ue_metro\\ui\\assets\\ue_metro_main_atlas.inkatlas");
  }
}

@addField(WorldMapMenuGameController)
let nctcGuideProbeContainer: wref<inkWidget>;

@addField(WorldMapMenuGameController)
let nctcGuideProbeButton: wref<NCTCGuideProbeButton>;

@addMethod(WorldMapMenuGameController)
private final func NCTCCreatePocketGuideProbe() -> Void {
  let root: ref<inkCompoundWidget>;
  let parent: ref<inkCompoundWidget>;
  let buttonsContainer: ref<inkCompoundWidget>;

  LogChannel(n"DEBUG", "[NCTC] PocketGuide probe: create requested");

  if IsDefined(this.nctcGuideProbeButton) {
    LogChannel(n"DEBUG", "[NCTC] PocketGuide probe: already exists");
    return;
  };

  root = this.GetRootCompoundWidget();
  if !IsDefined(root) {
    LogChannel(n"DEBUG", "[NCTC] PocketGuide probe: root missing");
    return;
  };

  parent = root.GetWidgetByPathName(n"Content") as inkCompoundWidget;
  if !IsDefined(parent) {
    LogChannel(n"DEBUG", "[NCTC] PocketGuide probe: Content missing");
    return;
  };

  // Same layout recipe as Metro Pocket Guide, only one row higher.
  buttonsContainer = new inkCanvas();
  buttonsContainer.SetName(n"NCTCProbeButtonsContainer");
  buttonsContainer.SetAnchor(inkEAnchor.BottomCenter);
  buttonsContainer.SetFitToContent(true);
  buttonsContainer.SetInteractive(false);
  buttonsContainer.SetAnchorPoint(0.5, 1.0);
  buttonsContainer.SetMargin(0.0, 0.0, 0.0, 320.0);
  buttonsContainer.Reparent(parent);
  this.nctcGuideProbeContainer = buttonsContainer;

  this.nctcGuideProbeButton = NCTCGuideProbeButton.Create();
  this.nctcGuideProbeButton.SetName(n"NCTCProbeButton");
  this.nctcGuideProbeButton.SetText("NCTC BUS NETWORK");
  this.nctcGuideProbeButton.RegisterToCallback(n"OnClick", this, n"OnNCTCGuideProbeClick");
  this.nctcGuideProbeButton.Reparent(buttonsContainer);

  LogChannel(n"DEBUG", "[NCTC] PocketGuide probe: button reparented");
}

@addMethod(WorldMapMenuGameController)
protected cb func OnNCTCGuideProbeClick(evt: ref<inkPointerEvent>) -> Bool {
  if !evt.IsAction(n"click") {
    return false;
  };

  LogChannel(n"DEBUG", "[NCTC] PocketGuide probe: click");
  this.PlaySound(n"Button", n"OnPress");

  if !IsDefined(this.nctcGuidePanel) {
    this.NCTCCreatePocketGuide();
  };

  if IsDefined(this.nctcGuidePanel) {
    this.nctcGuideVisible = !this.nctcGuideVisible;
    this.nctcGuidePanel.SetVisible(this.nctcGuideVisible);
    if this.nctcGuideVisible {
      this.nctcGuideProbeButton.SetText("CLOSE NCTC NETWORK");
      this.NCTCGuideReload();
    } else {
      this.nctcGuideProbeButton.SetText("NCTC BUS NETWORK");
    };
  } else {
    this.nctcGuideProbeButton.SetText("NCTC UI ERROR");
    LogChannel(n"DEBUG", "[NCTC] PocketGuide probe: guide panel missing after create");
  };

  evt.Handle();
  return true;
}
