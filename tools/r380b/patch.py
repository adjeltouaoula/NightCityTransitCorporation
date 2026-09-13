from pathlib import Path
import sys

root = Path(sys.argv[1])
transit = root / "source/redscript/NCTC/NCTCTransitSystem.reds"
s = transit.read_text()

def once(old: str, new: str, name: str) -> None:
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"{name} anchor failed: {n}")
    s = s.replace(old, new, 1)

once(
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38001);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38002);',
    "runtime revision",
)

# Pause only the bay spline. startFromClosest=true on resume makes the same
# world spline continue from the bus's current physical position.
anchor = '''  // Adaptive NCTC service speed. The game district supplies the zone profile'''
insert = '''  // r380b: safety stop for a bay spline. The route state remains owned by
  // NCTC; once the short obstacle probe is clear, DriveOnBaySpline resumes the
  // same spline from the closest point.
  public func PauseBaySplineForObstacle() -> Void {
    let noDriver: ref<AIEvent>;
    if !this.IsReady() { return; };
    this.NextDriveGeneration();
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleOnSplineCommand", false, true);
    this.activeSplineCommand = null;
    noDriver = new AIEvent();
    noDriver.name = n"NoDriver";
    this.bus.QueueEvent(noDriver);
  }

''' + anchor
once(anchor, insert, "PauseBaySpline insertion")

# Vanilla-style short swept box: same SpatialQueriesSystem.Overlap primitive
# used by game scripts. Vehicle catches traffic; Dynamic catches puppets and
# physics objects. Static is deliberately excluded because the validated bay
# spline already accounts for road/curb geometry and Static would false-hit it.
anchor = '''  // Native physics overlap is authoritative for bay occupancy. TargetingSystem
  // does not reliably enumerate parked traffic vehicles.
  private func IsBayOccupiedByVehicle() -> Bool {'''
probe = '''  // r380b: generic moving safety probe for bay manoeuvres. The box starts
  // beyond the Mahir's nose and follows its CURRENT heading, so it naturally
  // follows the curve instead of using H2-specific world coordinates.
  private func IsImmediateBayPathBlocked() -> Bool {
    let spatial: ref<SpatialQueriesSystem>;
    let vehicleResult: TraceResult;
    let dynamicResult: TraceResult;
    let dimensions: Vector4;
    let rotation: EulerAngles;
    let center: Vector4;
    let forward: Vector4;
    let vehicleBlocked: Bool;
    let dynamicBlocked: Bool;
    let halfWidth: Float;
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());

    spatial = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
    if !IsDefined(spatial) || !IsDefined(this.controller) { return false; };
    forward = Vector4.Normalize2D(this.controller.GetWorldForward());
    if AbsF(forward.X) <= 0.01 && AbsF(forward.Y) <= 0.01 { return false; };

    // 8 m long detection corridor, beginning 6.5 m ahead of the vehicle pivot.
    // Width tracks the surveyed bay width with a small safety margin.
    halfWidth = MaxF(this.GetBayWidth() * 0.50 + 0.25, 1.50);
    dimensions = new Vector4(halfWidth, 4.00, 1.75, 0.00);
    center = this.controller.GetWorldPosition() + forward * 10.50;
    center.Z += 1.25;
    rotation = Quaternion.ToEulerAngles(Quaternion.BuildFromDirectionVector(forward));

    vehicleBlocked = spatial.Overlap(dimensions, center, rotation, n"Vehicle", vehicleResult);
    dynamicBlocked = spatial.Overlap(dimensions, center, rotation, n"Dynamic", dynamicResult);
    if IsDefined(quests) {
      quests.SetFact(n"nctc_dev_bay_obstacle_vehicle", vehicleBlocked ? 1 : 0);
      quests.SetFact(n"nctc_dev_bay_obstacle_dynamic", dynamicBlocked ? 1 : 0);
      quests.SetFact(n"nctc_dev_bay_obstacle_blocked", vehicleBlocked || dynamicBlocked ? 1 : 0);
    };
    return vehicleBlocked || dynamicBlocked;
  }

''' + anchor
once(anchor, probe, "bay safety probe insertion")

# Departure: do not start the spline while its immediate swept corridor is occupied.
old = '''        if Equals(this.requestedStopId, 70) {
          this.bayParkingStage = 12;
          this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };'''
new = '''        if Equals(this.requestedStopId, 70) {
          if this.IsImmediateBayPathBlocked() {
            this.bayParkingStage = 15;
            this.driveCommandSent = true;
            this.PublishLoopDiagnostic(79, this.requestedStopId);
            this.ScheduleDispatch(0.10);
            return;
          };
          this.bayParkingStage = 12;
          this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };'''
once(old, new, "departure preflight")

# Arrival: if something crosses the mouth before the spline begins, cancel the
# normal road command and hold in the dedicated bay state instead of creeping on.
old = '''      if entryLongitudinal > 0.50 && entryLongitudinal <= 24.00 && entryLateral <= 12.00 {
        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 6.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingStage = 10;
        this.bayParkingWasEntered = true;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/arrival_spline", entrySpeed, true);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 68 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };'''
new = '''      if entryLongitudinal > 0.50 && entryLongitudinal <= 24.00 && entryLateral <= 12.00 {
        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 6.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingRetryCount = 0;
        if this.IsImmediateBayPathBlocked() {
          this.controller.CancelTrafficRoute();
          this.bayParkingStage = 17;
          this.bayParkingWasEntered = false;
          this.driveCommandSent = true;
          this.PublishLoopDiagnostic(82, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };
        this.bayParkingStage = 10;
        this.bayParkingWasEntered = true;
        this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/arrival_spline", entrySpeed, true);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 68 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };'''
once(old, new, "arrival preflight")

# Dedicated wait/resume stages are inserted before normal spline completion handling.
anchor = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 10) {'''
wait_stages = '''    // r380b departure preflight hold. Two consecutive clear probes avoid
    // launching into a one-frame gap in crossing traffic.
    if this.bayParkingActive && Equals(this.bayParkingStage, 15) {
      if this.IsImmediateBayPathBlocked() {
        this.bayParkingRetryCount = 0;
        quests.SetFact(n"nctc_dev_bay_obstacle_clear_polls", 0);
        this.PublishLoopDiagnostic(79, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      this.bayParkingRetryCount += 1;
      quests.SetFact(n"nctc_dev_bay_obstacle_clear_polls", this.bayParkingRetryCount);
      if this.bayParkingRetryCount < 2 {
        this.ScheduleDispatch(0.10);
        return;
      };
      this.bayParkingRetryCount = 0;
      this.bayParkingStage = 12;
      this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", 2.00, false);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 81 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.10);
      return;
    };

    // Departure was already on the spline when a Vehicle/Dynamic obstacle
    // entered the short swept corridor. Wait, then resume from closest point.
    if this.bayParkingActive && Equals(this.bayParkingStage, 16) {
      if this.IsImmediateBayPathBlocked() {
        this.bayParkingRetryCount = 0;
        quests.SetFact(n"nctc_dev_bay_obstacle_clear_polls", 0);
        this.PublishLoopDiagnostic(80, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      this.bayParkingRetryCount += 1;
      quests.SetFact(n"nctc_dev_bay_obstacle_clear_polls", this.bayParkingRetryCount);
      if this.bayParkingRetryCount < 2 {
        this.ScheduleDispatch(0.10);
        return;
      };
      this.bayParkingRetryCount = 0;
      this.bayParkingStage = 12;
      this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", 2.00, false);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 81 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.10);
      return;
    };

    // Arrival can be held before entering or paused mid-spline. The same
    // startFromClosest spline resumes once the immediate path is clear twice.
    if this.bayParkingActive && Equals(this.bayParkingStage, 17) {
      if this.IsImmediateBayPathBlocked() {
        this.bayParkingRetryCount = 0;
        quests.SetFact(n"nctc_dev_bay_obstacle_clear_polls", 0);
        this.PublishLoopDiagnostic(82, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      this.bayParkingRetryCount += 1;
      quests.SetFact(n"nctc_dev_bay_obstacle_clear_polls", this.bayParkingRetryCount);
      if this.bayParkingRetryCount < 2 {
        this.ScheduleDispatch(0.10);
        return;
      };
      this.bayParkingRetryCount = 0;
      this.bayParkingStage = 10;
      this.bayParkingWasEntered = true;
      this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/arrival_spline", 2.00, true);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 83 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.10);
      return;
    };

''' + anchor
once(anchor, wait_stages, "obstacle wait stages")

# Active arrival: completion/failure wins; otherwise a newly entered obstacle pauses it.
old = '''      if this.controller.IsSplineCommandFailed() {
        this.bayParkingStage = 11;
        this.PublishLoopDiagnostic(70, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 11) {'''
new = '''      if this.controller.IsSplineCommandFailed() {
        this.bayParkingStage = 11;
        this.PublishLoopDiagnostic(70, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      if this.IsImmediateBayPathBlocked() {
        this.controller.PauseBaySplineForObstacle();
        this.bayParkingStage = 17;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = true;
        this.PublishLoopDiagnostic(82, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 11) {'''
once(old, new, "arrival active obstacle pause")

# Active departure: completion/failure wins; otherwise pause on immediate obstacle.
old = '''      if this.controller.IsSplineCommandFailed() {
        this.bayParkingStage = 13;
        this.PublishLoopDiagnostic(75, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 14) {'''
new = '''      if this.controller.IsSplineCommandFailed() {
        this.bayParkingStage = 13;
        this.PublishLoopDiagnostic(75, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      if this.IsImmediateBayPathBlocked() {
        this.controller.PauseBaySplineForObstacle();
        this.bayParkingStage = 16;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = true;
        this.PublishLoopDiagnostic(80, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 14) {'''
once(old, new, "departure active obstacle pause")

transit.write_text(s)

cet = root / "source/cet/nctc_survey/init.lua"
c = cet.read_text()

def conce(old: str, new: str, name: str) -> None:
    global c
    n = c.count(old)
    if n != 1:
        raise SystemExit(f"{name} anchor failed: {n}")
    c = c.replace(old, new, 1)

conce(
    '''    [78] = "route loop: r380a JoinTraffic fallback -> r376f route handoff"
  }''',
    '''    [78] = "route loop: r380a JoinTraffic fallback -> r376f route handoff",
    [79] = "route loop: r380b departure held by bay obstacle",
    [80] = "route loop: r380b departure spline paused by bay obstacle",
    [81] = "route loop: r380b departure path clear -> spline resumed",
    [82] = "route loop: r380b arrival held/paused by bay obstacle",
    [83] = "route loop: r380b arrival path clear -> spline resumed"
  }''',
    "CET obstacle labels",
)

conce(
    '''  if code == 74 or code == 76 or code == 77 or code == 78 then''',
    '''  if code == 79 or code == 80 or code == 81 or code == 82 or code == 83 then
    command_extra = command_extra
      .. " obstacle=" .. tostring(fact(quests, "nctc_dev_bay_obstacle_blocked"))
      .. " vehicle=" .. tostring(fact(quests, "nctc_dev_bay_obstacle_vehicle"))
      .. " dynamic=" .. tostring(fact(quests, "nctc_dev_bay_obstacle_dynamic"))
      .. " clearPolls=" .. tostring(fact(quests, "nctc_dev_bay_obstacle_clear_polls"))
  end
  if code == 74 or code == 76 or code == 77 or code == 78 then''',
    "CET obstacle telemetry",
)

conce(
    'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 or code == 76 or code == 77 or code == 78 then',
    'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 or code == 76 or code == 77 or code == 78 or code == 79 or code == 80 or code == 81 or code == 82 or code == 83 then',
    "CET state list",
)

conce(
    '''  if revision == 38001 then
    log("NCTC runtime build=38001 r380a exact vanilla JoinTraffic rejoin")''',
    '''  if revision == 38002 then
    log("NCTC runtime build=38002 r380b vanilla join + bay Vehicle/Dynamic obstacle guard")
  elseif revision == 38001 then
    log("NCTC runtime build=38001 r380a exact vanilla JoinTraffic rejoin")''',
    "CET build revision",
)

cet.write_text(c)
