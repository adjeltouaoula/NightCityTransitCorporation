from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, got {n}")
    return text.replace(old, new, 1)


transit = Path("source/redscript/NCTC/NCTCTransitSystem.reds")
s = transit.read_text()

# Controller state: keep the native JoinTraffic command so its lifecycle can be
# inspected before NCTC submits the normal route command.
s = replace_once(
    s,
    "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let driveGeneration: Int32;",
    "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let activeJoinTrafficCommand: ref<AIVehicleJoinTrafficCommand>;\n  private let driveGeneration: Int32;",
    "join command field",
)

s = replace_once(
    s,
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37606);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37802);',
    "runtime revision",
)

old_handoff = '''  // r376b: the departure spline has already completed successfully here,
  // so do not interrupt it again. Hand the measured rolling speed to the
  // normal traffic navigator through the established generation-safe pulse.
  public func DriveToTrafficAfterSpline(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let speedProfile: Int32;
    let speedLimit: Float;
    let generation: Int32;
    if !this.IsReady() { return false; };

    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;

    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00));

    callback = new NCTCDeferredDriveCommand();
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(this.bus, this, target, minimumDistance, speedLimit, speedProfile, MaxF(startSpeed, 0.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }
'''

new_handoff = '''  // r378b: r376f already gets the Mahir cleanly out of H2. Use native
  // JoinTraffic only as a local lane-acquisition phase, then validate the
  // traffic movement direction before giving the route navigator control.
  public func JoinTrafficAfterSpline() -> Bool {
    let command: ref<AIVehicleJoinTrafficCommand>;
    if !this.IsReady() { return false; };

    this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    this.activeJoinTrafficCommand = null;

    command = new AIVehicleJoinTrafficCommand();
    command.needDriver = false;
    command.useKinematic = false;
    this.bus.GetAIComponent().SendCommand(command);
    this.activeJoinTrafficCommand = command;
    return true;
  }

  public func IsInTrafficLane() -> Bool {
    return this.IsReady() && this.bus.IsInTrafficLane();
  }

  // VehicleObject owns a CrowdMemberBaseComponent, the same native traffic
  // component used by the game's crowd/traffic behavior. Its movement vector
  // tells us which direction the selected traffic path actually runs.
  public func GetTrafficMovementDirection() -> Vector4 {
    let crowd: ref<CrowdMemberBaseComponent>;
    let direction: Vector4;
    if !this.IsReady() { return new Vector4(0.00, 0.00, 0.00, 0.00); };
    crowd = this.bus.GetCrowdMemberComponent();
    if !IsDefined(crowd) { return new Vector4(0.00, 0.00, 0.00, 0.00); };
    direction = crowd.GetMovementDirection();
    direction.Z = 0.00;
    direction.W = 0.00;
    if AbsF(direction.X) <= 0.01 && AbsF(direction.Y) <= 0.01 {
      return new Vector4(0.00, 0.00, 0.00, 0.00);
    };
    return Vector4.Normalize2D(direction);
  }

  public func TryChangeTrafficMovementDirection() -> Bool {
    let crowd: ref<CrowdMemberBaseComponent>;
    if !this.IsReady() { return false; };
    crowd = this.bus.GetCrowdMemberComponent();
    if !IsDefined(crowd) { return false; };
    crowd.TryChangeMovementDirection();
    return true;
  }

  public func IsJoinTrafficCommandSuccessful() -> Bool {
    return IsDefined(this.activeJoinTrafficCommand) && Equals(this.activeJoinTrafficCommand.state, AICommandState.Success);
  }

  public func IsJoinTrafficCommandFailed() -> Bool {
    if !IsDefined(this.activeJoinTrafficCommand) { return false; };
    return Equals(this.activeJoinTrafficCommand.state, AICommandState.Failure)
      || Equals(this.activeJoinTrafficCommand.state, AICommandState.Cancelled)
      || Equals(this.activeJoinTrafficCommand.state, AICommandState.Interrupted);
  }

  public func GetJoinTrafficCommandStatusCode() -> Int32 {
    if !IsDefined(this.activeJoinTrafficCommand) { return 0; };
    if Equals(this.activeJoinTrafficCommand.state, AICommandState.Success) { return 2; };
    if this.IsJoinTrafficCommandFailed() { return 3; };
    return 1;
  }

  public func DriveToTrafficAfterJoin(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let speedProfile: Int32;
    let speedLimit: Float;
    let generation: Int32;
    if !this.IsReady() { return false; };

    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleJoinTrafficCommand", false, true);
    this.activeJoinTrafficCommand = null;
    this.activeRouteCommand = null;

    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00));

    callback = new NCTCDeferredDriveCommand();
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(this.bus, this, target, minimumDistance, speedLimit, speedProfile, MaxF(startSpeed, 0.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }
'''

s = replace_once(s, old_handoff, new_handoff, "direction filtered spline handoff")

# Persist the desired travel direction before AdvanceToNextStop replaces the
# current stop's bay geometry with the successor stop profile.
s = replace_once(
    s,
    "  private let passageForward: Vector4;\n  private let passageForwardRecorded: Bool;",
    "  private let passageForward: Vector4;\n  private let passageForwardRecorded: Bool;\n  private let departureJoinForward: Vector4;\n  private let departureJoinFlipCount: Int32;",
    "direction filter state fields",
)

old_telemetry = '''      if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
        this.PublishLoopDiagnostic(71, this.requestedStopId);
      } else {
        if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
          this.PublishLoopDiagnostic(73, this.requestedStopId);
        } else {
          this.PublishRouteCommandTelemetry();
        };
      };'''

new_telemetry = '''      if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
        this.PublishLoopDiagnostic(71, this.requestedStopId);
      } else {
        if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
          this.PublishLoopDiagnostic(73, this.requestedStopId);
        } else {
          if this.bayParkingActive && (Equals(this.bayParkingStage, 14) || Equals(this.bayParkingStage, 15)) {
            this.PublishJoinDirectionFacts(quests);
            this.PublishLoopDiagnostic(76, this.requestedStopId);
          } else {
            this.PublishRouteCommandTelemetry();
          };
        };
      };'''

s = replace_once(s, old_telemetry, new_telemetry, "join telemetry")

old_stage = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
      if this.controller.IsSplineCommandSuccessful() {
        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
        if !this.AdvanceToNextStop() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        this.legPolls = 0;
        this.bayParkingActive = false;
        this.bayParkingStage = 0;
        this.driveCommandSent = this.controller.DriveToTrafficAfterSpline(this.GetTrafficTarget(), 0.00, rollingSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 74 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsSplineCommandFailed() {
        this.bayParkingStage = 13;
        this.PublishLoopDiagnostic(75, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 13) {
      this.ScheduleDispatch(0.25);
      return;
    };'''

new_stage = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
      if this.controller.IsSplineCommandSuccessful() {
        // Capture the bay's authored travel direction BEFORE loading the next
        // stop, because AdvanceToNextStop replaces surveyBerth/P2/forward.
        this.departureJoinForward = Vector4.Normalize2D(this.GetBayForward());
        if !this.AdvanceToNextStop() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        this.legPolls = 0;
        // AdvanceToNextStop deliberately resets bay state; re-arm the join
        // phase explicitly. This fixes the r378a state-machine bug.
        this.bayParkingActive = true;
        this.bayParkingStage = 14;
        this.bayParkingRetryCount = 0;
        this.departureJoinFlipCount = 0;
        this.driveCommandSent = this.controller.JoinTrafficAfterSpline();
        this.PublishJoinDirectionFacts(quests);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 74 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      if this.controller.IsSplineCommandFailed() {
        this.bayParkingStage = 13;
        this.PublishLoopDiagnostic(75, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 13) {
      this.ScheduleDispatch(0.25);
      return;
    };

    // Direction-filtered native traffic join. A movement vector aligned with
    // the bay forward is accepted; the opposite traffic path is rejected and
    // asked to reverse once through the vehicle's native CrowdMember component.
    if this.bayParkingActive && (Equals(this.bayParkingStage, 14) || Equals(this.bayParkingStage, 15)) {
      let movement: Vector4 = this.controller.GetTrafficMovementDirection();
      let movementValid: Bool = AbsF(movement.X) > 0.01 || AbsF(movement.Y) > 0.01;
      let directionDot: Float = movementValid ? Vector4.Dot(movement, this.departureJoinForward) : -2.00;
      this.bayParkingRetryCount += 1;
      this.PublishJoinDirectionFacts(quests);

      // Reject an explicitly opposite path immediately. Vanilla exposes this
      // exact direction-change operation on the vehicle CrowdMember component.
      if movementValid && directionDot <= -0.25 && this.departureJoinFlipCount < 1 {
        if this.controller.TryChangeTrafficMovementDirection() {
          this.departureJoinFlipCount += 1;
          this.bayParkingStage = 15;
          this.PublishJoinDirectionFacts(quests);
          this.PublishLoopDiagnostic(79, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };
      };

      // Do not hand a cross-street/opposite lane to DriveToPoint. Require both
      // native lane membership and a clearly compatible path direction.
      if this.controller.IsInTrafficLane() && movementValid && directionDot >= 0.30 {
        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
        this.bayParkingActive = false;
        this.bayParkingStage = 0;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = this.controller.DriveToTrafficAfterJoin(this.GetTrafficTarget(), 0.00, rollingSpeed);
        this.PublishJoinDirectionFacts(quests);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 77 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };

      if this.controller.IsJoinTrafficCommandFailed() {
        this.bayParkingStage = 16;
        this.PublishJoinDirectionFacts(quests);
        this.PublishLoopDiagnostic(78, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };

      // Five seconds is ample for a local native join. On a bad/ambiguous lane
      // hold the experiment instead of reproducing r376f's unsafe handoff.
      if this.bayParkingRetryCount >= 50 {
        this.bayParkingStage = 16;
        this.PublishJoinDirectionFacts(quests);
        this.PublishLoopDiagnostic(80, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 16) {
      this.ScheduleDispatch(0.25);
      return;
    };'''

s = replace_once(s, old_stage, new_stage, "direction filtered stage 12 handoff")

# Add a compact diagnostic publisher next to the existing route telemetry.
old_diag = '''  private func PublishRouteCommandTelemetry() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_dev_command_state", this.controller.GetRouteCommandStatusCode());
    quests.SetFact(n"nctc_dev_previous_command_state", this.controller.GetPreviousRouteCommandStatusCode());
    quests.SetFact(n"nctc_dev_command_speed_mm", Cast<Int32>(this.controller.GetCurrentSpeed() * 1000.00));
    this.PublishLoopDiagnostic(36, this.requestedStopId);
  }
'''

new_diag = '''  private func PublishJoinDirectionFacts(quests: ref<QuestsSystem>) -> Void {
    let movement: Vector4;
    let dot: Float = -2.00;
    if !IsDefined(quests) || !IsDefined(this.controller) { return; };
    movement = this.controller.GetTrafficMovementDirection();
    if (AbsF(movement.X) > 0.01 || AbsF(movement.Y) > 0.01)
      && (AbsF(this.departureJoinForward.X) > 0.01 || AbsF(this.departureJoinForward.Y) > 0.01) {
      dot = Vector4.Dot(movement, this.departureJoinForward);
    };
    quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
    quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);
    quests.SetFact(n"nctc_dev_join_move_x_mm", Cast<Int32>(movement.X * 1000.00));
    quests.SetFact(n"nctc_dev_join_move_y_mm", Cast<Int32>(movement.Y * 1000.00));
    quests.SetFact(n"nctc_dev_join_desired_x_mm", Cast<Int32>(this.departureJoinForward.X * 1000.00));
    quests.SetFact(n"nctc_dev_join_desired_y_mm", Cast<Int32>(this.departureJoinForward.Y * 1000.00));
    quests.SetFact(n"nctc_dev_join_direction_dot_x1000", Cast<Int32>(dot * 1000.00));
    quests.SetFact(n"nctc_dev_join_flip_count", this.departureJoinFlipCount);
  }

  private func PublishRouteCommandTelemetry() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_dev_command_state", this.controller.GetRouteCommandStatusCode());
    quests.SetFact(n"nctc_dev_previous_command_state", this.controller.GetPreviousRouteCommandStatusCode());
    quests.SetFact(n"nctc_dev_command_speed_mm", Cast<Int32>(this.controller.GetCurrentSpeed() * 1000.00));
    this.PublishLoopDiagnostic(36, this.requestedStopId);
  }
'''

s = replace_once(s, old_diag, new_diag, "join direction diagnostic publisher")
transit.write_text(s)


cet = Path("source/cet/nctc_survey/init.lua")
c = cet.read_text()

c = replace_once(
    c,
    '    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",\n    [75] = "route loop: r376b H2 native departure spline FAILED"',
    '    [74] = "route loop: r378b H2 spline exit -> direction-filtered JoinTraffic armed",\n    [75] = "route loop: r376b H2 native departure spline FAILED",\n    [76] = "route loop: r378b direction-filtered JoinTraffic telemetry",\n    [77] = "route loop: r378b compatible traffic direction -> route handoff",\n    [78] = "route loop: r378b native JoinTraffic FAILED",\n    [79] = "route loop: r378b opposite traffic direction -> native direction flip requested",\n    [80] = "route loop: r378b traffic direction unresolved/rejected timeout"',
    "diagnostic labels",
)

c = replace_once(
    c,
    "  if code == 48 or code == 49 or code == 54 then",
    '''  if code == 74 or code == 76 or code == 77 or code == 78 or code == 79 or code == 80 then
    local join_states = { [0] = "missing", [1] = "active", [2] = "success", [3] = "failed/cancelled" }
    command_extra = command_extra
      .. " joinState=" .. (join_states[fact(quests, "nctc_dev_join_traffic_state")] or "unknown")
      .. " inTrafficLane=" .. tostring(fact(quests, "nctc_dev_bus_in_traffic_lane"))
      .. string.format(" trafficDir=(%.3f, %.3f)", fact(quests, "nctc_dev_join_move_x_mm") / 1000.0, fact(quests, "nctc_dev_join_move_y_mm") / 1000.0)
      .. string.format(" desiredDir=(%.3f, %.3f)", fact(quests, "nctc_dev_join_desired_x_mm") / 1000.0, fact(quests, "nctc_dev_join_desired_y_mm") / 1000.0)
      .. " dirDot=" .. string.format("%.3f", fact(quests, "nctc_dev_join_direction_dot_x1000") / 1000.0)
      .. " flips=" .. tostring(fact(quests, "nctc_dev_join_flip_count"))
  end
  if code == 48 or code == 49 or code == 54 then''',
    "join direction diagnostic details",
)

c = replace_once(
    c,
    "or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 then",
    "or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 or code == 76 or code == 77 or code == 78 or code == 79 or code == 80 then",
    "detailed diagnostic list",
)

c = replace_once(
    c,
    '  if revision == 37606 then\n    log("NCTC runtime build=37606 r376f H2 final nose clearance")',
    '  if revision == 37802 then\n    log("NCTC runtime build=37802 r378b H2 direction-filtered JoinTraffic")\n  elseif revision == 37606 then\n    log("NCTC runtime build=37606 r376f H2 final nose clearance")',
    "build log",
)

cet.write_text(c)
