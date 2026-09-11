from pathlib import Path


def replace_one(path, old, new):
    p = Path(path)
    s = p.read_text()
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one occurrence, got {count}: {old[:160]!r}")
    p.write_text(s.replace(old, new))

# --- REDscript -------------------------------------------------------------
path = Path("source/redscript/NCTC/NCTCTransitSystem.reds")
s = path.read_text()

def r(old, new):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"Transit: expected one occurrence, got {count}: {old[:180]!r}")
    s = s.replace(old, new)

r('SetFact(n"nctc_dev_build_revision", 37421);', 'SetFact(n"nctc_dev_build_revision", 37422);')

r('''  public static func TryGetBerth2(game: GameInstance, stopId: Int32, out berth2: Vector4, out forward: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let prefix: String = "nctc_external_capture_id" + ToString(stopId) + "_berth2_";
    if !IsDefined(quests) || !Equals(quests.GetFact(StringToName(prefix + "valid")), 1) { return false; };
    berth2 = NCTCServiceProfiles.ReadVector(quests, prefix);
    if AbsF(berth2.X) < 1.00 && AbsF(berth2.Y) < 1.00 { return false; };
    forward = new Vector4(0.00, 0.00, 0.00, 0.00);
    if Equals(quests.GetFact(StringToName(prefix + "forward_valid")), 1) {
      forward = new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "forward_x"))) / 1000000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "forward_y"))) / 1000000.00, 0.00, 0.00);
      forward = Vector4.Normalize2D(forward);
    };
    return true;
  }
''', '''  public static func TryGetBerth2(game: GameInstance, stopId: Int32, out berth2: Vector4, out forward: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let prefix: String = "nctc_external_capture_id" + ToString(stopId) + "_berth2_";
    if !IsDefined(quests) || !Equals(quests.GetFact(StringToName(prefix + "valid")), 1) { return false; };
    berth2 = NCTCServiceProfiles.ReadVector(quests, prefix);
    if AbsF(berth2.X) < 1.00 && AbsF(berth2.Y) < 1.00 { return false; };
    forward = new Vector4(0.00, 0.00, 0.00, 0.00);
    if Equals(quests.GetFact(StringToName(prefix + "forward_valid")), 1) {
      forward = new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "forward_x"))) / 1000000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "forward_y"))) / 1000000.00, 0.00, 0.00);
      forward = Vector4.Normalize2D(forward);
    };
    return true;
  }

  public static func TryGetBayWidth(game: GameInstance, stopId: Int32, out width: Float) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    let prefix: String = "nctc_external_capture_id" + ToString(stopId) + "_bay_width_";
    if !IsDefined(quests) || !Equals(quests.GetFact(StringToName(prefix + "valid")), 1) { return false; };
    width = Cast<Float>(quests.GetFact(StringToName(prefix + "mm"))) / 1000.00;
    return width >= 2.00 && width <= 5.00;
  }
''')

r('''  private let surveyBerth2: Vector4;
  private let surveyBerth2Forward: Vector4;
  private let hasSurveyBerth2: Bool;
  private let surveyYaw: Float;''', '''  private let surveyBerth2: Vector4;
  private let surveyBerth2Forward: Vector4;
  private let hasSurveyBerth2: Bool;
  private let surveyBayWidth: Float;
  private let hasSurveyBayWidth: Bool;
  private let surveyYaw: Float;''')

r('''  private let departureAttackTarget: Vector4;
  private let departureRoadTarget: Vector4;
  private let departureCurveStage: Int32;''', '''  private let departureAttackTarget: Vector4;
  private let departureRecoveryTarget: Vector4;
  private let departureRoadTarget: Vector4;
  private let departureCurveStage: Int32;
  private let departureStallPolls: Int32;''')

r('''  // r374t: Point targets are curve controls, not destinations. Every stage
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
''', '''  // r374v: the calibrated bay is a narrow physical corridor. Never manufacture
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
''')

r('''  private func GetBayExitAttackTarget() -> Vector4 {
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
''', '''  private func GetBayExitAttackTarget() -> Vector4 {
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
''')

r('''  // r374t: service departure starts steering toward the road before P2,
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
''', '''  // r374v: start the nose toward the exit while keeping the pivot inside the
  // calibrated bay envelope. A direct-mode centreline recovery target is kept
  // as a watchdog escape; it never hands the bus to native traffic while deep.
  private func ArmDepartureManeuver() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let forward: Vector4 = this.GetBayForward();
    let exit: Vector4 = this.GetBayExitPoint();
    this.departureStart = this.controller.GetWorldPosition();
    this.departureForward = forward;
    this.departureExitPoint = exit;
    this.departureAttackTarget = this.GetBayExitAttackTarget();
    this.departureRecoveryTarget = exit + forward * ClampF(this.GetBayWidth() * 0.65, 1.75, 2.25);
    this.departureRoadTarget = this.GetBayRoadRejoinTarget();
    this.departureCurveStage = 1;
    this.departureStallPolls = 0;
    this.departureManeuverActive = true;
    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_departure_target_x_mm", Cast<Int32>(this.departureRoadTarget.X * 1000.00));
      quests.SetFact(n"nctc_dev_departure_target_y_mm", Cast<Int32>(this.departureRoadTarget.Y * 1000.00));
      quests.SetFact(n"nctc_dev_departure_target_z_mm", Cast<Int32>(this.departureRoadTarget.Z * 1000.00));
      quests.SetFact(n"nctc_dev_departure_progress_mm", Cast<Int32>(this.GetDepartureProgress() * 1000.00));
      quests.SetFact(n"nctc_dev_departure_speed_mm", 0);
    };
  }
''')

# Publish calibrated width in loop diagnostics.
r('''    quests.SetFact(n"nctc_dev_loop_bay_length_mm", this.HasServiceBay() ? Cast<Int32>(Vector4.Distance(this.surveyBerth, this.surveyBerth2) * 1000.00) : 0);''', '''    quests.SetFact(n"nctc_dev_loop_bay_length_mm", this.HasServiceBay() ? Cast<Int32>(Vector4.Distance(this.surveyBerth, this.surveyBerth2) * 1000.00) : 0);
    quests.SetFact(n"nctc_dev_loop_bay_width_mm", this.HasServiceBay() ? Cast<Int32>(this.GetBayWidth() * 1000.00) : 0);''')

# Initial profile load.
r('''    this.surveyBerth2Forward = new Vector4(0.00, 0.00, 0.00, 0.00);
    this.hasSurveyBerth2 = false;
    this.hasSurveyProfile = NCTCServiceProfiles.TryGet(this.GetGameInstance(), line, stopId, this.surveySpawn, this.surveyApproach, this.surveyBerth, this.surveyYaw);
    NCTCServiceProfiles.TryGetBerthForward(this.GetGameInstance(), stopId, this.surveyBerthForward);
    this.hasSurveyBerth2 = NCTCServiceProfiles.TryGetBerth2(this.GetGameInstance(), stopId, this.surveyBerth2, this.surveyBerth2Forward);''', '''    this.surveyBerth2Forward = new Vector4(0.00, 0.00, 0.00, 0.00);
    this.hasSurveyBerth2 = false;
    this.surveyBayWidth = 0.00;
    this.hasSurveyBayWidth = false;
    this.hasSurveyProfile = NCTCServiceProfiles.TryGet(this.GetGameInstance(), line, stopId, this.surveySpawn, this.surveyApproach, this.surveyBerth, this.surveyYaw);
    NCTCServiceProfiles.TryGetBerthForward(this.GetGameInstance(), stopId, this.surveyBerthForward);
    this.hasSurveyBerth2 = NCTCServiceProfiles.TryGetBerth2(this.GetGameInstance(), stopId, this.surveyBerth2, this.surveyBerth2Forward);
    this.hasSurveyBayWidth = NCTCServiceProfiles.TryGetBayWidth(this.GetGameInstance(), stopId, this.surveyBayWidth);''')

# Reset counters at new service.
r('''    this.departureManeuverActive = false;
    this.departureCurveStage = 0;
    this.approachSlowdownApplied = false;''', '''    this.departureManeuverActive = false;
    this.departureCurveStage = 0;
    this.departureStallPolls = 0;
    this.approachSlowdownApplied = false;''')

# Force a modest direct-mode kick when leaving the service stop.
r('''        this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureAttackTarget, 0.00);''', '''        this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureAttackTarget, 1.50);''')

# Replace departure state machine with stall-safe version.
r('''    if this.departureManeuverActive {
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
''', '''    if this.departureManeuverActive {
      let departureProgress: Float = this.GetDepartureProgress();
      let departureSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
      let departureKickSpeed: Float = MaxF(MinF(departureSpeed, 7.00), 1.50);
      this.departureStallPolls += 1;
      if departureSpeed > 0.40 { this.departureStallPolls = 0; };
      quests.SetFact(n"nctc_dev_departure_progress_mm", Cast<Int32>(departureProgress * 1000.00));
      quests.SetFact(n"nctc_dev_departure_speed_mm", Cast<Int32>(departureSpeed * 1000.00));
      if Equals(this.departureCurveStage, 1) {
        if departureProgress >= -3.25 || this.controller.IsNear(this.departureAttackTarget, 2.75) {
          this.departureCurveStage = 2;
          this.departureStallPolls = 0;
          this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureRoadTarget, departureKickSpeed);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 53 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.05); return;
        };
        if this.departureStallPolls >= 25 {
          this.departureStallPolls = 0;
          this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureRecoveryTarget, 1.50);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 54 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.08); return;
        };
        if this.controller.IsRouteCommandFailed() {
          this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureAttackTarget, departureKickSpeed);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 52 : 33, this.requestedStopId);
        };
        this.ScheduleDispatch(0.08); return;
      };
      if this.controller.IsNear(this.departureRoadTarget, 4.00) && departureProgress >= 1.00 {
        this.departureManeuverActive = false; this.departureCurveStage = 0; this.departureStallPolls = 0; this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToTrafficAfterRollingPassage(this.GetTrafficTarget(), 0.00, departureSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 49 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05); return;
      };
      if this.departureStallPolls >= 25 || this.controller.IsRouteCommandFailed() {
        this.departureStallPolls = 0;
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.departureRoadTarget, departureKickSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 54 : 33, this.requestedStopId);
      };
      this.ScheduleDispatch(0.08); return;
    };
''')

# Entry trigger: use measured road/bay lateral offset as a real 5-6:1 taper.
r('''      let entryDistance: Float = Vector4.Distance(this.controller.GetWorldPosition(), this.GetBayEntryPoint());
      if entryLongitudinal > 0.50
        && entryDistance <= 46.00
        && (entryLateral <= 18.50 || entryDistance <= 25.00) {
        let berthForward: Vector4 = this.GetBerthForward();''', '''      let entryDistance: Float = Vector4.Distance(this.controller.GetWorldPosition(), this.GetBayEntryPoint());
      let attackRunIn: Float = ClampF(entryLateral * 6.00, 18.00, 28.00);
      if entryLongitudinal > 0.50
        && entryLongitudinal <= attackRunIn
        && entryDistance <= 32.00
        && entryLateral <= 12.00 {
        let berthForward: Vector4 = this.GetBerthForward();''')

r('''        let berthEntrySpeed: Float = MinF(AbsF(this.controller.GetCurrentSpeed()), 7.00);''', '''        let berthEntrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 7.00), 1.00);''')

# Stage 1: cross P1 close to the centreline; no huge 4m proximity handoff.
r('''      if gateProgress >= -0.75 || this.controller.IsNear(this.GetBayEntryLeadTarget(), 4.00) {
        this.berthWasEntered = true;''', '''      let entryTolerance: Float = ClampF(this.GetBayWidth() * 0.45, 1.10, 1.45);
      if (gateProgress >= -0.25 && AbsF(gateLateral) <= entryTolerance)
        || gateProgress >= this.GetBayWidth() * 0.80 {
        this.berthWasEntered = true;''')

# Stage 2: require a much tighter centreline before TRACK; bounded fallback.
r('''      if (counterProgress >= bayLength * 0.24 && AbsF(counterLateral) <= 3.00)
        || counterProgress >= bayLength * 0.34 {''', '''      let counterTolerance: Float = ClampF(this.GetBayWidth() * 0.40, 1.00, 1.30);
      if (counterProgress >= bayLength * 0.28 && AbsF(counterLateral) <= counterTolerance)
        || counterProgress >= bayLength * 0.42 {''')

r('''      if trackProgress >= bayLength * 0.54 {''', '''      if trackProgress >= bayLength * 0.58 {''')
r('''      if exitProgress >= bayLength * 0.78 || this.controller.IsNear(this.GetBayExitAttackTarget(), 4.00) {''', '''      if exitProgress >= bayLength * 0.84 || this.controller.IsNear(this.GetBayExitAttackTarget(), 2.75) {''')

# Successor profile load keeps its own calibrated width.
r('''    this.surveyBerth2Forward = new Vector4(0.00, 0.00, 0.00, 0.00);
    this.hasSurveyBerth2 = false;
    NCTCServiceProfiles.TryGetBerthForward(this.GetGameInstance(), nextStopId, this.surveyBerthForward);
    this.hasSurveyBerth2 = NCTCServiceProfiles.TryGetBerth2(this.GetGameInstance(), nextStopId, this.surveyBerth2, this.surveyBerth2Forward);
    this.surveyYaw = nextYaw;''', '''    this.surveyBerth2Forward = new Vector4(0.00, 0.00, 0.00, 0.00);
    this.hasSurveyBerth2 = false;
    this.surveyBayWidth = 0.00;
    this.hasSurveyBayWidth = false;
    NCTCServiceProfiles.TryGetBerthForward(this.GetGameInstance(), nextStopId, this.surveyBerthForward);
    this.hasSurveyBerth2 = NCTCServiceProfiles.TryGetBerth2(this.GetGameInstance(), nextStopId, this.surveyBerth2, this.surveyBerth2Forward);
    this.hasSurveyBayWidth = NCTCServiceProfiles.TryGetBayWidth(this.GetGameInstance(), nextStopId, this.surveyBayWidth);
    this.surveyYaw = nextYaw;''')

path.write_text(s)

# --- CET -------------------------------------------------------------------
path = Path("source/cet/nctc_survey/init.lua")
s = path.read_text()

def c(old, new):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"CET: expected one occurrence, got {count}: {old[:180]!r}")
    s = s.replace(old, new)

# Publish calibrated width from the two authoring points to REDscript.
c('''  publish_vector("spawn", capture.spawn)
  publish_vector("approach", capture.approach)
  publish_vector("berth", capture.berth)
  publish_vector("berth2", capture.berth2)
end''', '''  publish_vector("spawn", capture.spawn)
  publish_vector("approach", capture.approach)
  publish_vector("berth", capture.berth)
  publish_vector("berth2", capture.berth2)
  local width_prefix = "nctc_external_capture_id" .. tostring(capture.stopId or 0) .. "_bay_width_"
  if vector_has_position(capture.bayWidthA) and vector_has_position(capture.bayWidthB) then
    local dx = (capture.bayWidthA.x or 0) - (capture.bayWidthB.x or 0)
    local dy = (capture.bayWidthA.y or 0) - (capture.bayWidthB.y or 0)
    local width = math.sqrt(dx * dx + dy * dy)
    set_fact(quests, width_prefix .. "mm", math.floor(width * 1000))
    set_fact(quests, width_prefix .. "valid", 1)
  else
    set_fact(quests, width_prefix .. "mm", 0)
    set_fact(quests, width_prefix .. "valid", 0)
  end
end''')

# Width in diagnostics and r374v labels.
c('''  local bay_length = fact(quests, "nctc_dev_loop_bay_length_mm") / 1000.0
  local bay_p1_x''', '''  local bay_length = fact(quests, "nctc_dev_loop_bay_length_mm") / 1000.0
  local bay_width = fact(quests, "nctc_dev_loop_bay_width_mm") / 1000.0
  local bay_p1_x''')

c('''    [43] = "route loop: r374t S-curve ENTRY ATTACK",
    [44] = "route loop: r374t S-curve COUNTER-STEER",''', '''    [43] = "route loop: r374v WIDTH-AWARE ENTRY ATTACK",
    [44] = "route loop: r374v centreline COUNTER-STEER",''')

c('''    [48] = "route loop: r374t service departure S-curve armed",
    [49] = "route loop: r374t traffic handoff after S-curve rejoin",
    [50] = "route loop: r374t native Vehicle overlap -> stay on road",
    [51] = "route loop: r374t TRACK BAY",
    [52] = "route loop: r374t EXIT ATTACK",
    [53] = "route loop: r374t REJOIN counter-steer"''', '''    [48] = "route loop: r374v service departure armed",
    [49] = "route loop: r374v traffic handoff after measured rejoin",
    [50] = "route loop: r374v native Vehicle overlap -> stay on road",
    [51] = "route loop: r374v TRACK narrow bay",
    [52] = "route loop: r374v EXIT ATTACK inside bay envelope",
    [53] = "route loop: r374v 3-to-1 REJOIN counter-steer",
    [54] = "route loop: r374v direct departure stall recovery"''')

c('''  if code == 48 or code == 49 then''', '''  if code == 48 or code == 49 or code == 54 then''')

c('''  if code == 29 or code == 30 or code == 36 or code == 43 or code == 47 or code == 48 or code == 49 or code == 50 or code == 51 or code == 52 or code == 53 then''', '''  if code == 29 or code == 30 or code == 36 or code == 43 or code == 47 or code == 48 or code == 49 or code == 50 or code == 51 or code == 52 or code == 53 or code == 54 then''')

c('''      .. " bayLen=" .. string.format("%.2fm", bay_length)
      .. string.format(" P1=(%.3f, %.3f) P2=(%.3f, %.3f)", bay_p1_x, bay_p1_y, bay_p2_x, bay_p2_y)''', '''      .. " bayLen=" .. string.format("%.2fm", bay_length)
      .. " bayWidth=" .. string.format("%.3fm", bay_width)
      .. string.format(" P1=(%.3f, %.3f) P2=(%.3f, %.3f)", bay_p1_x, bay_p1_y, bay_p2_x, bay_p2_y)''')

c('''  if revision == 37421 then
    log("NCTC runtime build=37421 r374u bay-width calibration")''', '''  if revision == 37422 then
    log("NCTC runtime build=37422 r374v calibrated narrow-bay geometry + departure recovery")
  elseif revision == 37421 then
    log("NCTC runtime build=37421 r374u bay-width calibration")''')

path.write_text(s)
print("r374v patch applied")
