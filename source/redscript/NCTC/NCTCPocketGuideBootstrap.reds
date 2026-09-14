module NCTC

// World-map fallback bootstrap for the Pocket Guide.
// OnEntityAttached fires after the map controller has been initialized and
// attached to its entity, which gives us a second, later point where the
// Content widget hierarchy is guaranteed to exist.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnEntityAttached() -> Bool {
  let result: Bool = wrappedMethod();

  if !IsDefined(this.nctcGuideButton) {
    this.NCTCCreatePocketGuide();
  };

  return result;
}
