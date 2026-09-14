module NCTC

// r386c: a bay's passenger-service point is off the traffic lane. Giving that
// point (or a point beyond it on the bay centreline) to AIVehicleDriveToPoint
// can make vanilla traffic navigation take a large loop before the arrival
// spline gets control. Keep the traffic command on the road-side corridor that
// the generated arrival spline already uses, then hand off to the spline near
// P1. Intermediate/unrequested bay stops use the same road corridor with a
// long lead so they remain true pass-through points.
@replaceMethod(NCTCTransitSystem)
private func GetTrafficTarget() -> Vector4 {
  let target: Vector4 = this.GetServiceBerth();
  let forward: Vector4;
  let right: Vector4;
  let sideOffset: Float;
  let sideSign: Float;
  let lead: Float;

  if this.followingPassage {
    // Preserve the validated passage behaviour: the target stays far beyond
    // the waypoint so the native controller never treats it as a stop.
    if AbsF(this.passageForward.X) > 0.01 || AbsF(this.passageForward.Y) > 0.01 {
      return this.passageTarget + this.passageForward * 100.00;
    };
    return this.passageTarget;
  };

  if this.HasServiceBay() {
    forward = this.GetBayForward();
    if AbsF(forward.X) > 0.01 || AbsF(forward.Y) > 0.01 {
      right = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
      sideOffset = MaxF(this.GetBayWidth() * 0.50 + 2.75, 4.20);
      sideSign = this.NCTCBayRoadSideSign();
      // The generic arrival spline starts 22 m before P1 on this same road
      // line. A +18 m lead leaves ~40 m of native road target beyond that
      // first spline point, preventing premature braking while still avoiding
      // any target inside/after the bay itself.
      lead = Equals(this.requestedStopId, this.serviceStopId) ? 18.00 : 100.00;
      return this.GetBayEntryPoint() + forward * lead + right * sideOffset * sideSign;
    };
  };

  if AbsF(this.surveyBerthForward.X) > 0.01 || AbsF(this.surveyBerthForward.Y) > 0.01 {
    // Preserve roadside-stop behaviour exactly as before r386c.
    if !this.HasServiceBay() && !Equals(this.requestedStopId, this.serviceStopId) {
      return target + this.surveyBerthForward * 100.00;
    };
    return target + this.surveyBerthForward * 13.70;
  };
  return target;
}
