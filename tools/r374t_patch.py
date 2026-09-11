from pathlib import Path

p = Path('source/redscript/NCTC/NCTCTransitSystem.reds')
s = p.read_text()

def one(old, new):
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'expected one occurrence, got {n}: {old[:100]!r}')
    s = s.replace(old, new)

one('GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37419);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37420);')

one('''  private let departureExitPoint: Vector4;
  private let departureRoadTarget: Vector4;
''', '''  private let departureExitPoint: Vector4;
  private let departureAttackTarget: Vector4;
  private let departureRoadTarget: Vector4;
  private let departureCurveStage: Int32;
''')

start = s.index('  private func GetBayEntryLeadTarget() -> Vector4 {')
end = s.index('  // Native physics overlap is authoritative for bay occupancy.', start)
new_helpers = '''  // r374t: Point targets are curve controls, not destinations. Every stage
  // hands off before the target so the Mahir keeps rolling through an S-curve.
  private func GetBayEntryLeadTarget() -> Vector4 {
    let entry: Vector4 = this.GetBayEntryPoint();
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let length: Float = Vector4.Distance(this.GetBayEntryPoint(), this.GetBayExitPoint());
    let side: Float = this.berthMergeSignedLateral >= 0.00 ? 1.00 : -1.00;
    let overshoot: Float = ClampF(AbsF(this.berthMergeSignedLateral) * 0.12, 1.50, 2.40);
    let lead: Float = ClampF(length * 0.20, 5.50, 7.50);
    return entry + forward * lead + right * side * overshoot;
  }

  private func GetBayCounterTarget() -> Vector4 {
    let entry: Vector4 = this.GetBayEntryPoint();
    let forward: Vector4 = this.GetBayForward();
    let length: Float = Vector4.Distance(entry, this.GetBayExitPoint());
    return entry + forward * length * 0.42;
  }

  private func GetBayTrackTarget() -> Vector4 {
    let entry: Vector4 = this.GetBayEntryPoint();
    let forward: Vector4 = this.GetBayForward();
    let length: Float = Vector4.Distance(entry, this.GetBayExitPoint());
    return entry + forward * length * 0.70;
  }

  private func GetBayProgress(out lateral: Float) -> Float {
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let delta: Vector4 = this.controller.GetWorldPosition() - this.GetBayEntryPoint();
    lateral = Vector4.Dot(delta, right);
    return Vector4.Dot(delta, forward);
  }

  private func GetBayEntryProgress(out lateral: Float) -> Float {
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let delta: Vector4 = this.GetBayEntryPoint() - this.controller.GetWorldPosition();
    lateral = AbsF(Vector4.Dot(delta, right));
    return Vector4.Dot(delta, forward);
  }

  private func GetBayRoadLateral() -> Float {
    let measured: Float = this.berthGateRoadSignedLateral;
    if AbsF(measured) >= 1.00 {
      return measured > 0.00
        ? ClampF(measured * 1.05, 2.35, 3.60)
        : ClampF(measured * 1.05, -3.60, -2.35);
    };
    return ClampF(-this.berthMergeSignedLateral * 0.18, -2.50, 2.50);
  }

  private func GetBayExitAttackTarget() -> Vector4 {
    let entry: Vector4 = this.GetBayEntryPoint();
    let exit: Vector4 = this.GetBayExitPoint();
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let length: Float = Vector4.Distance(entry, exit);
    let roadLateral: Float = this.GetBayRoadLateral();
    return exit - forward * ClampF(length * 0.10, 3.00, 4.25) + right * roadLateral * 0.68;
  }

  private func GetBayRoadRejoinTarget() -> Vector4 {
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let roadLateral: Float = this.GetBayRoadLateral();
    return this.GetBayExitPoint() + forward * 4.50 + right * roadLateral;
  }

'''
s = s[:start] + new_helpers + s[end:]

start = s.index('  // Leave on a shallow arc toward the road-side envelope measured at entry.')
end = s.index('  private func GetDepartureProgress() -> Float {', start)
new_departure = '''  // r374t: service departure starts steering toward the road before P2,
  // then counter-steers to the stored road envelope after P2.
  private func ArmDepartureManeuver() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let forward: Vector4 = this.GetBayForward();
    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
    let entry: Vector4 = this.GetBayEntryPoint();
    let exit: Vector4 = this.GetBayExitPoint();
    let length: Float = Vector4.Distance(entry, exit);
    let roadLateral: Float = this.GetBayRoadLateral();
    this.departureStart = this.controller.GetWorldPosition();
    this.departureForward = forward;
    this.departureExitPoint = exit;
    this.departureAttackTarget = exit - forward * ClampF(length * 0.10, 3.00, 4.25) + right * roadLateral * 0.68;
    this.departureRoadTarget = exit + forward * 4.50 + right * roadLateral;
    this.departureCurveStage = 1;
    this.departureManeuverActive = true;
    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_departure_target_x_mm", Cast<Int32>(this.departureRoadTarget.X * 1000.00));
      quests.SetFact(n"nctc_dev_departure_target_y_mm", Cast<Int32>(this.departureRoadTarget.Y * 1000.00));
      quests.SetFact(n"nctc_dev_departure_target_z_mm", Cast<Int32>(this.departureRoadTarget.Z * 1000.00));
      quests.SetFact(n"nctc_dev_departure_progress_mm", Cast<Int32>(this.GetDepartureProgress() * 1000.00));
      quests.SetFact(n"nctc_dev_departure_speed_mm", 0);
    };
  }

'''
s = s[:start] + new_departure + s[end:]

one('''  private func GetActiveBerthTarget() -> Vector4 {
    if Equals(this.berthManeuverStage, 1) { return this.GetBayEntryLeadTarget(); };
    if Equals(this.berthManeuverStage, 2) {
      return Equals(this.requestedStopId, this.serviceStopId)
        ? this.GetBerthCorridorTarget()
        : this.GetBayRoadRejoinTarget();
    };
    return this.GetServiceBerth();
  }
''', '''  private func GetActiveBerthTarget() -> Vector4 {
    if Equals(this.berthManeuverStage, 1) { return this.GetBayEntryLeadTarget(); };
    if Equals(this.berthManeuverStage, 2) { return this.GetBayCounterTarget(); };
    if Equals(this.berthManeuverStage, 3) {
      return Equals(this.requestedStopId, this.serviceStopId)
        ? this.GetBerthCorridorTarget()
        : this.GetBayTrackTarget();
    };
    if Equals(this.berthManeuverStage, 4) { return this.GetBayExitAttackTarget(); };
    if Equals(this.berthManeuverStage, 5) { return this.GetBayRoadRejoinTarget(); };
    return this.GetServiceBerth();
  }
''')
one('        && entryDistance <= 60.00\n', '        && entryDistance <= 46.00\n')

start = s.index('    // Cross Point 1 on the short lead target')
end = s.index('    // r374m: keep the single corridor command alive through arrival.', start)
new_stages = '''    // r374t stage 1 — ENTRY ATTACK. Aim slightly through the bay axis so the
    // nose commits early; capture the local road offset only close to P1.
    if this.berthManeuverActive && Equals(this.berthManeuverStage, 1) && this.HasServiceBay() {
      let gateLateral: Float;
      let gateProgress: Float = this.GetBayProgress(gateLateral);
      let stageSpeed: Float = MinF(AbsF(this.controller.GetCurrentSpeed()), 7.00);
      if gateProgress >= -12.00 && gateProgress <= -1.00 && AbsF(gateLateral) <= 6.00 {
        this.berthGateRoadSignedLateral = gateLateral;
      };
      if gateProgress >= -0.75 || this.controller.IsNear(this.GetBayEntryLeadTarget(), 4.00) {
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
      this.ScheduleDispatch(0.05);
      return;
    };

    // r374t stage 2 — COUNTER-STEER back to the bay axis while the rear follows.
    if this.berthManeuverActive && Equals(this.berthManeuverStage, 2) && this.HasServiceBay() {
      let counterLateral: Float;
      let counterProgress: Float = this.GetBayProgress(counterLateral);
      let bayLength: Float = Vector4.Distance(this.GetBayEntryPoint(), this.GetBayExitPoint());
      let stageSpeed: Float = MinF(AbsF(this.controller.GetCurrentSpeed()), 7.00);
      if (counterProgress >= bayLength * 0.24 && AbsF(counterLateral) <= 3.00)
        || counterProgress >= bayLength * 0.34 {
        this.berthManeuverStage = 3;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(
          Equals(this.requestedStopId, this.serviceStopId) ? this.GetBerthCorridorTarget() : this.GetBayTrackTarget(),
          stageSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 51 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsRouteCommandFailed() {
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayCounterTarget(), stageSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 44 : 33, this.requestedStopId);
      };
      this.ScheduleDispatch(0.05);
      return;
    };

    // r374t stage 3 — TRACK BAY. Pass-through buses stay on-axis until 54%.
    if this.berthManeuverActive && Equals(this.berthManeuverStage, 3)
      && this.HasServiceBay() && !Equals(this.requestedStopId, this.serviceStopId) {
      let trackLateral: Float;
      let trackProgress: Float = this.GetBayProgress(trackLateral);
      let bayLength: Float = Vector4.Distance(this.GetBayEntryPoint(), this.GetBayExitPoint());
      let stageSpeed: Float = MinF(AbsF(this.controller.GetCurrentSpeed()), 7.00);
      if trackProgress >= bayLength * 0.54 {
        this.berthManeuverStage = 4;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayExitAttackTarget(), stageSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 52 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsRouteCommandFailed() {
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayTrackTarget(), stageSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 51 : 33, this.requestedStopId);
      };
      this.ScheduleDispatch(0.05);
      return;
    };

    // r374t stage 4 — EXIT ATTACK before P2, while the rear is still in bay.
    if this.berthManeuverActive && Equals(this.berthManeuverStage, 4)
      && this.HasServiceBay() && !Equals(this.requestedStopId, this.serviceStopId) {
      let exitLateral: Float;
      let exitProgress: Float = this.GetBayProgress(exitLateral);
      let bayLength: Float = Vector4.Distance(this.GetBayEntryPoint(), this.GetBayExitPoint());
      let stageSpeed: Float = MinF(AbsF(this.controller.GetCurrentSpeed()), 7.00);
      if exitProgress >= bayLength * 0.78 || this.controller.IsNear(this.GetBayExitAttackTarget(), 4.00) {
        this.berthManeuverStage = 5;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayRoadRejoinTarget(), stageSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 53 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsRouteCommandFailed() {
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayExitAttackTarget(), stageSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 52 : 33, this.requestedStopId);
      };
      this.ScheduleDispatch(0.05);
      return;
    };

    // r374t stage 5 — counter-steer to the road and only then restore traffic.
    if this.berthManeuverActive && Equals(this.berthManeuverStage, 5)
      && this.HasServiceBay() && !Equals(this.requestedStopId, this.serviceStopId) {
      let rejoinLateral: Float;
      let rejoinProgress: Float = this.GetBayProgress(rejoinLateral);
      let bayLength: Float = Vector4.Distance(this.GetBayEntryPoint(), this.GetBayExitPoint());
      let rejoinSpeed: Float = MinF(AbsF(this.controller.GetCurrentSpeed()), 7.00);
      if rejoinProgress >= bayLength + 0.75 && this.controller.IsNear(this.GetBayRoadRejoinTarget(), 4.00) {
        this.berthManeuverActive = false;
        this.berthManeuverStage = 0;
        this.approachSlowdownApplied = false;
        this.legPolls = 0;
        if !this.AdvanceToNextStop() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        this.driveCommandSent = this.controller.DriveToTrafficAfterRollingPassage(this.GetTrafficTarget(), 0.00, rejoinSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 49 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsRouteCommandFailed() {
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetBayRoadRejoinTarget(), rejoinSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 53 : 33, this.requestedStopId);
      };
      this.ScheduleDispatch(0.08);
      return;
    };

'''
s = s[:start] + new_stages + s[end:]

one('        this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureRoadTarget, 0.00);\n',
    '        this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureAttackTarget, 0.00);\n')

start = s.index('    if this.departureManeuverActive {')
end = s.index('    this.legPolls += 1;', start)
new_dep_loop = '''    if this.departureManeuverActive {
      let departureProgress: Float = this.GetDepartureProgress();
      let departureSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
      quests.SetFact(n"nctc_dev_departure_progress_mm", Cast<Int32>(departureProgress * 1000.00));
      quests.SetFact(n"nctc_dev_departure_speed_mm", Cast<Int32>(departureSpeed * 1000.00));
      if Equals(this.departureCurveStage, 1) {
        if departureProgress >= -4.25 || this.controller.IsNear(this.departureAttackTarget, 3.50) {
          this.departureCurveStage = 2;
          this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureRoadTarget, MinF(departureSpeed, 7.00));
          this.PublishLoopDiagnostic(this.driveCommandSent ? 53 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.05); return;
        };
        if this.controller.IsRouteCommandFailed() {
          this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureAttackTarget, MinF(departureSpeed, 7.00));
          this.PublishLoopDiagnostic(this.driveCommandSent ? 52 : 33, this.requestedStopId);
        };
        this.ScheduleDispatch(0.08); return;
      };
      if this.controller.IsNear(this.departureRoadTarget, 3.50) && departureProgress >= 0.75 {
        this.departureManeuverActive = false; this.departureCurveStage = 0; this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToTrafficAfterRollingPassage(this.GetTrafficTarget(), 0.00, departureSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 49 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05); return;
      };
      if this.controller.IsRouteCommandFailed() {
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureRoadTarget, MinF(departureSpeed, 7.00));
        this.PublishLoopDiagnostic(this.driveCommandSent ? 53 : 33, this.requestedStopId);
      };
      this.ScheduleDispatch(0.08); return;
    };

'''
s = s[:start] + new_dep_loop + s[end:]

s = s.replace('    this.departureManeuverActive = false;\n', '    this.departureManeuverActive = false;\n    this.departureCurveStage = 0;\n')
p.write_text(s)

lua = Path('source/cet/nctc_survey/init.lua')
l = lua.read_text()
l = l.replace('[43] = "route loop: r374s early POINT1_GATE direct command sent",', '[43] = "route loop: r374t S-curve ENTRY ATTACK",')
l = l.replace('[44] = "route loop: r374s Point1 gate -> bay corridor handoff",', '[44] = "route loop: r374t S-curve COUNTER-STEER",')
l = l.replace('[48] = "route loop: r374s local-gate road rejoin departure",', '[48] = "route loop: r374t service departure S-curve armed",')
l = l.replace('[49] = "route loop: r374s traffic handoff after local road rejoin",', '[49] = "route loop: r374t traffic handoff after S-curve rejoin",')
l = l.replace('[50] = "route loop: r374s native Vehicle overlap -> stay on road"', '[50] = "route loop: r374t native Vehicle overlap -> stay on road",\n    [51] = "route loop: r374t TRACK BAY",\n    [52] = "route loop: r374t EXIT ATTACK",\n    [53] = "route loop: r374t REJOIN counter-steer"')
l = l.replace('if code == 29 or code == 30 or code == 36 or code == 43 or code == 47 or code == 48 or code == 49 or code == 50 then', 'if code == 29 or code == 30 or code == 36 or code == 43 or code == 47 or code == 48 or code == 49 or code == 50 or code == 51 or code == 52 or code == 53 then')
l = l.replace('if berth_active == 1 or code == 43 or code == 44 or code == 45 then', 'if berth_active == 1 or code == 43 or code == 44 or code == 45 or code == 51 or code == 52 or code == 53 then')
l = l.replace('  if revision == 37419 then\n    log("NCTC runtime build=37419 r374s early Point1 gate + local road rejoin")', '  if revision == 37420 then\n    log("NCTC runtime build=37420 r374t real-bus S-curve bay path")\n  elseif revision == 37419 then\n    log("NCTC runtime build=37419 r374s early Point1 gate + local road rejoin")')
lua.write_text(l)

text = p.read_text()
for needle in ['nctc_dev_build_revision", 37420','GetBayCounterTarget','GetBayTrackTarget','GetBayExitAttackTarget','berthManeuverStage = 5','departureCurveStage = 2','IsBayOccupiedByVehicle','spatial.Overlap']:
    if needle not in text:
        raise SystemExit('missing ' + needle)
