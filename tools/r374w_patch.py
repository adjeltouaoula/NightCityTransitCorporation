from pathlib import Path

TRANSIT = Path('source/redscript/NCTC/NCTCTransitSystem.reds')
CET = Path('source/cet/nctc_survey/init.lua')

def replace_once(text, old, new):
    if old not in text:
        raise SystemExit('missing pattern:\n' + old[:160])
    return text.replace(old, new, 1)

t = TRANSIT.read_text()
c = CET.read_text()

t = replace_once(t, 'SetFact(n"nctc_dev_build_revision", 37422);', 'SetFact(n"nctc_dev_build_revision", 37423);')

t = replace_once(t, '''  // Point 1/2 define the real bay axis. The service target remains deep in
  // the bay, but r374r first aims at a short lead point just inside Point 1.
  // The handoff happens at the entry gate (not mid-bay), so the nose enters
  // early and the steering can unwind along the bay instead of cutting a
  // straight chord from the road to the deep service target.
  private func GetBerthCorridorTarget() -> Vector4 {
    let forward: Vector4 = this.GetBerthForward();
    return this.GetServiceBerth() + forward * 4.00;
  }

  // r374v: the calibrated bay is a narrow physical corridor. Never manufacture
  // steering angle by aiming through the far edge. The first target stays on
  // the bay centreline; the real S comes from a short 5-6:1 road-to-bay run-in
  // followed by an on-axis counter-steer.
  private func GetBayWidth() -> Float {
    return this.hasSurveyBayWidth ? ClampF(this.surveyBayWidth, 2.20, 3.60) : 2.90;
  }

  private func GetBayEntryLeadTarget() -> Vector4 {
    let entry: Vector4 = this.GetBayEntryPoint();
    let forward: Vector4 = this.GetBayForward();
    let lead: Float = ClampF(this.GetBayWidth() * 1.05, 2.60, 3.40);
    return entry + forward * lead;
  }

  private func GetBayCounterTarget() -> Vector4 {
    let entry: Vector4 = this.GetBayEntryPoint();
    let forward: Vector4 = this.GetBayForward();
    let length: Float = Vector4.Distance(entry, this.GetBayExitPoint());
    return entry + forward * ClampF(length * 0.38, 9.00, 13.00);
  }

  private func GetBayTrackTarget() -> Vector4 {
    let entry: Vector4 = this.GetBayEntryPoint();
    let forward: Vector4 = this.GetBayForward();
    let length: Float = Vector4.Distance(entry, this.GetBayExitPoint());
    return entry + forward * length * 0.70;
  }
''', '''  // r374w: a DriveToPoint target is a destination, not a waypoint. r374v
  // proved that a short target 2-3 m inside P1 makes the native controller
  // brake to zero before the stage handoff. Every intermediate bay phase now
  // aims THROUGH its control point at a distant rolling target. NCTC switches
  // stages from geometry while the command is still pulling the bus forward.
  private func GetBerthCorridorTarget() -> Vector4 {
    let forward: Vector4 = this.GetBerthForward();
    return this.GetServiceBerth() + forward * 1.25;
  }

  private func GetBayWidth() -> Float {
    return this.hasSurveyBayWidth ? ClampF(this.surveyBayWidth, 2.20, 3.60) : 2.90;
  }

  private func GetBayEntryLeadTarget() -> Vector4 {
    let entry: Vector4 = this.GetBayEntryPoint();
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let width: Float = this.GetBayWidth();
    let roadOffset: Float = -this.berthMergeSignedLateral;
    let runIn: Float = ClampF(AbsF(roadOffset) * 5.00, 18.00, 28.00);
    let gateLead: Float = ClampF(width * 1.00, 2.50, 3.20);
    let virtualRoad: Vector4 = entry - forward * runIn + right * roadOffset;
    let gate: Vector4 = entry + forward * gateLead;
    let ray: Vector4 = Vector4.Normalize2D(gate - virtualRoad);
    return gate + ray * 10.00;
  }

  private func GetBayCounterTarget() -> Vector4 {
    let exit: Vector4 = this.GetBayExitPoint();
    let forward: Vector4 = this.GetBayForward();
    return exit + forward * 12.00;
  }

  private func GetBayTrackTarget() -> Vector4 {
    let exit: Vector4 = this.GetBayExitPoint();
    let forward: Vector4 = this.GetBayForward();
    return exit + forward * 14.00;
  }
''')

t = replace_once(t, '''  private func GetBayRoadLateral() -> Float {
    let measured: Float = this.berthGateRoadSignedLateral;
    if AbsF(measured) >= 1.00 {
      return measured > 0.00
        ? ClampF(measured * 1.05, 2.35, 3.60)
        : ClampF(measured * 1.05, -3.60, -2.35);
    };
    return ClampF(-this.berthMergeSignedLateral * 0.18, -2.50, 2.50);
  }

  private func GetBayExitAttackTarget() -> Vector4 {
    let exit: Vector4 = this.GetBayExitPoint();
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let roadLateral: Float = this.GetBayRoadLateral();
    let width: Float = this.GetBayWidth();
    let attackMagnitude: Float = ClampF(AbsF(roadLateral) * 0.20, 0.45, width * 0.28);
    let attackLateral: Float = roadLateral >= 0.00 ? attackMagnitude : -attackMagnitude;
    let preExit: Float = ClampF(width * 1.20, 3.20, 4.00);
    return exit - forward * preExit + right * attackLateral;
  }

  private func GetBayRoadRejoinTarget() -> Vector4 {
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let roadLateral: Float = this.GetBayRoadLateral();
    // Real pull-out geometry is much closer to a 3:1 taper than r374t's
    // 4.5-m diagonal. Give the rear axle room to clear the bay before native
    // traffic is restored.
    let rejoinLead: Float = ClampF(AbsF(roadLateral) * 3.00, 8.00, 12.50);
    return this.GetBayExitPoint() + forward * rejoinLead + right * roadLateral;
  }
''', '''  private func GetBayRoadLateral() -> Float {
    let measured: Float = this.berthGateRoadSignedLateral;
    let signSource: Float = AbsF(measured) >= 0.75 ? measured : -this.berthMergeSignedLateral;
    let magnitude: Float = ClampF(this.GetBayWidth() * 1.08, 2.75, 3.80);
    return signSource >= 0.00 ? magnitude : -magnitude;
  }

  private func GetBayExitAttackTarget() -> Vector4 {
    let exit: Vector4 = this.GetBayExitPoint();
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let roadLateral: Float = this.GetBayRoadLateral();
    let width: Float = this.GetBayWidth();
    let lead: Float = ClampF(width * 2.00, 5.50, 7.20);
    return exit + forward * lead + right * roadLateral * 0.42;
  }

  private func GetBayRoadRejoinTarget() -> Vector4 {
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let roadLateral: Float = this.GetBayRoadLateral();
    let rejoinLead: Float = ClampF(AbsF(roadLateral) * 3.00, 8.50, 12.50);
    return this.GetBayExitPoint() + forward * rejoinLead + right * roadLateral;
  }
''')

t = replace_once(t, '''      let entryTolerance: Float = ClampF(this.GetBayWidth() * 0.45, 1.10, 1.45);
      if (gateProgress >= -0.25 && AbsF(gateLateral) <= entryTolerance)
        || gateProgress >= this.GetBayWidth() * 0.80 {
        this.berthWasEntered = true;
        this.berthManeuverStage = 2;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayCounterTarget(), stageSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 44 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsRouteCommandFailed() {
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayEntryLeadTarget(), stageSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 43 : 33, this.requestedStopId);
      };
''', '''      let entryTolerance: Float = ClampF(this.GetBayWidth() * 0.55, 1.30, 1.85);
      let entryGateLead: Float = ClampF(this.GetBayWidth() * 1.00, 2.50, 3.20);
      if (gateProgress >= 0.75 && AbsF(gateLateral) <= entryTolerance)
        || gateProgress >= entryGateLead + 0.75
        || this.controller.IsRouteCommandSuccessful() {
        this.berthWasEntered = true;
        this.berthManeuverStage = 2;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayCounterTarget(), MaxF(stageSpeed, 2.50));
        this.PublishLoopDiagnostic(this.driveCommandSent ? 44 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsRouteCommandFailed() {
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayEntryLeadTarget(), MaxF(stageSpeed, 2.50));
        this.PublishLoopDiagnostic(this.driveCommandSent ? 43 : 33, this.requestedStopId);
      };
''')

t = replace_once(t, '''      let counterTolerance: Float = ClampF(this.GetBayWidth() * 0.40, 1.00, 1.30);
      if (counterProgress >= bayLength * 0.28 && AbsF(counterLateral) <= counterTolerance)
        || counterProgress >= bayLength * 0.42 {
        this.berthManeuverStage = 3;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(
          Equals(this.requestedStopId, this.serviceStopId) ? this.GetBerthCorridorTarget() : this.GetBayTrackTarget(),
          stageSpeed);
''', '''      let counterTolerance: Float = ClampF(this.GetBayWidth() * 0.48, 1.15, 1.70);
      if (counterProgress >= bayLength * 0.30 && AbsF(counterLateral) <= counterTolerance)
        || counterProgress >= bayLength * 0.46 {
        this.berthManeuverStage = 3;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(
          Equals(this.requestedStopId, this.serviceStopId) ? this.GetBerthCorridorTarget() : this.GetBayTrackTarget(),
          MaxF(stageSpeed, 2.50));
''')

t = replace_once(t, '''      if trackProgress >= bayLength * 0.58 {
        this.berthManeuverStage = 4;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayExitAttackTarget(), stageSpeed);''', '''      if trackProgress >= bayLength * 0.60 {
        this.berthManeuverStage = 4;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayExitAttackTarget(), MaxF(stageSpeed, 2.50));''')

t = replace_once(t, '''      if exitProgress >= bayLength * 0.84 || this.controller.IsNear(this.GetBayExitAttackTarget(), 2.75) {
        this.berthManeuverStage = 5;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayRoadRejoinTarget(), stageSpeed);''', '''      if exitProgress >= bayLength * 0.86 || this.controller.IsRouteCommandSuccessful() {
        this.berthManeuverStage = 5;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayRoadRejoinTarget(), MaxF(stageSpeed, 2.50));''')

t = replace_once(t, '      if rejoinProgress >= bayLength + 0.75 && this.controller.IsNear(this.GetBayRoadRejoinTarget(), 4.00) {', '      if (rejoinProgress >= bayLength + 0.75 && this.controller.IsNear(this.GetBayRoadRejoinTarget(), 4.50))\n        || (rejoinProgress >= bayLength + 0.50 && this.controller.IsRouteCommandSuccessful()) {')

t = t.replace('DriveToBerthDirect(this.departureAttackTarget, 1.50)', 'DriveToBerthDirect(this.departureAttackTarget, 2.50)', 1)

c = replace_once(c, '''  if revision == 37422 then
    log("NCTC runtime build=37422 r374v calibrated narrow-bay geometry + departure recovery")''', '''  if revision == 37423 then
    log("NCTC runtime build=37423 r374w rolling bay control rays")
  elseif revision == 37422 then
    log("NCTC runtime build=37422 r374v calibrated narrow-bay geometry + departure recovery")''')
for old, new in {
    'r374v WIDTH-AWARE ENTRY ATTACK': 'r374w ROLLING-RAY ENTRY ATTACK',
    'r374v centreline COUNTER-STEER': 'r374w LONG-CORRIDOR COUNTER-STEER',
    'r374v service departure armed': 'r374w rolling service departure armed',
    'r374v traffic handoff after measured rejoin': 'r374w traffic handoff after rolling rejoin',
    'r374v native Vehicle overlap -> stay on road': 'r374w native Vehicle overlap -> stay on road',
    'r374v TRACK narrow bay': 'r374w TRACK rolling centreline',
    'r374v EXIT ATTACK inside bay envelope': 'r374w ROLLING EXIT ATTACK',
    'r374v 3-to-1 REJOIN counter-steer': 'r374w 3-to-1 rolling REJOIN',
    'r374v direct departure stall recovery': 'r374w direct departure stall recovery',
}.items():
    if old not in c:
        raise SystemExit('missing CET label ' + old)
    c = c.replace(old, new)

TRANSIT.write_text(t)
CET.write_text(c)
