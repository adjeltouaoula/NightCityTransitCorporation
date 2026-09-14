module NCTC

// World-map fallback bootstrap for the Pocket Guide.
// OnEntityAttached fires after the map controller has been initialized and
// attached to its entity. Use the Metro-style probe here so we can prove the
// hook reaches the live Ink tree independently of the full guide panel.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnEntityAttached() -> Bool {
  let result: Bool = wrappedMethod();

  if !IsDefined(this.nctcGuideProbeButton) {
    this.NCTCCreatePocketGuideProbe();
  };

  return result;
}
