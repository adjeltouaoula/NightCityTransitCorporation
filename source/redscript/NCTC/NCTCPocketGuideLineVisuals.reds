module NCTC

// The Codeware HubLinkButton keeps the reliable hitbox/callback behaviour,
// but its HubMenu style bindings can resolve poorly inside our custom world-map
// panel. Draw explicit NCTC visuals on the same root so interaction and visuals
// are independent.
@addField(NCTCGuideLineButton)
private let nctcVisualBackground: wref<inkRectangle>;

@addField(NCTCGuideLineButton)
private let nctcVisualAccent: wref<inkRectangle>;

@addField(NCTCGuideLineButton)
private let nctcVisualLabel: wref<inkText>;

@wrapMethod(NCTCGuideLineButton)
protected cb func OnCreate() {
  wrappedMethod();

  // Make the original root an explicit 500x120 hitbox. It is scaled to 42%
  // by NCTCGuideLineButton, yielding a compact ~210x50 line selector.
  this.m_root.SetVisible(true);
  this.m_root.SetOpacity(1.00);

  // Do not depend on HubMenu style bindings for the visible text.
  this.m_label.SetVisible(false);

  this.nctcVisualBackground = new inkRectangle();
  this.nctcVisualBackground.SetName(n"NCTCLineButtonBackground");
  this.nctcVisualBackground.SetSize(Vector2(485.00, 108.00));
  this.nctcVisualBackground.SetMargin(inkMargin(8.00, 6.00, 0.00, 0.00));
  this.nctcVisualBackground.SetTintColor(new HDRColor(0.025, 0.055, 0.070, 0.96));
  this.nctcVisualBackground.SetInteractive(false);
  this.nctcVisualBackground.Reparent(this.m_root);

  this.nctcVisualAccent = new inkRectangle();
  this.nctcVisualAccent.SetName(n"NCTCLineButtonAccent");
  this.nctcVisualAccent.SetSize(Vector2(10.00, 108.00));
  this.nctcVisualAccent.SetMargin(inkMargin(8.00, 6.00, 0.00, 0.00));
  this.nctcVisualAccent.SetTintColor(new HDRColor(0.18, 0.92, 1.22, 1.00));
  this.nctcVisualAccent.SetInteractive(false);
  this.nctcVisualAccent.Reparent(this.m_root);

  this.nctcVisualLabel = new inkText();
  this.nctcVisualLabel.SetName(n"NCTCLineButtonLabel");
  this.nctcVisualLabel.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  this.nctcVisualLabel.SetFontStyle(n"Semi-Bold");
  this.nctcVisualLabel.SetFontSize(46);
  this.nctcVisualLabel.SetLetterCase(textLetterCase.UpperCase);
  this.nctcVisualLabel.SetText("LINE " + ToString(this.GetLine()));
  this.nctcVisualLabel.SetMargin(inkMargin(42.00, 3.00, 0.00, 0.00));
  this.nctcVisualLabel.SetSize(Vector2(420.00, 112.00));
  this.nctcVisualLabel.SetHorizontalAlignment(textHorizontalAlignment.Left);
  this.nctcVisualLabel.SetVerticalAlignment(textVerticalAlignment.Center);
  this.nctcVisualLabel.SetContentHAlign(inkEHorizontalAlign.Left);
  this.nctcVisualLabel.SetContentVAlign(inkEVerticalAlign.Center);
  this.nctcVisualLabel.SetTintColor(new HDRColor(0.72, 0.95, 1.05, 1.00));
  this.nctcVisualLabel.SetInteractive(false);
  this.nctcVisualLabel.Reparent(this.m_root);
}

@wrapMethod(NCTCGuideLineButton)
public func SetSelected(selected: Bool) -> Void {
  wrappedMethod(selected);

  // The original implementation dims the whole root. Keep that behaviour but
  // make the selected state visually unmistakable with explicit colors.
  if IsDefined(this.nctcVisualBackground) {
    if selected {
      this.nctcVisualBackground.SetTintColor(new HDRColor(0.045, 0.115, 0.140, 0.98));
    } else {
      this.nctcVisualBackground.SetTintColor(new HDRColor(0.020, 0.040, 0.052, 0.92));
    };
  };

  if IsDefined(this.nctcVisualAccent) {
    if selected {
      this.nctcVisualAccent.SetTintColor(new HDRColor(0.20, 1.12, 1.45, 1.00));
    } else {
      this.nctcVisualAccent.SetTintColor(new HDRColor(0.38, 0.52, 0.58, 0.85));
    };
  };

  if IsDefined(this.nctcVisualLabel) {
    if selected {
      this.nctcVisualLabel.SetTintColor(new HDRColor(0.76, 1.08, 1.22, 1.00));
    } else {
      this.nctcVisualLabel.SetTintColor(new HDRColor(0.62, 0.74, 0.79, 1.00));
    };
  };
}
