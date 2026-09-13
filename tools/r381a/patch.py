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
    "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let driveGeneration: Int32;",
    "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let activeJoinTrafficCommand: ref<AIVehicleJoinTrafficCommand>;\n  private let driveGeneration: Int32;",
    "join command field",
)

once(
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37606);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38101);',
    "runtime revision",
)

anchor = '''  // r376b: the departure spline has already completed successfully here,
  // so do not interrupt it again. Hand the measured rolling speed to the
  // normal traffic navigator through the established generation-safe pulse.
  public func DriveToTrafficAfterSpline(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {'''
methods = '''  // r381a: direct vanilla rejoin from the berth. No departure spline.
  // This mirrors the Delamain free-roam handoff: DriverReady, then the game's
  // dedicated AIVehicleJoinTrafficCommand with useKinematic=true.
  public func JoinTrafficDirectFromBerth() -> Bool {
    let driverReady: ref<AIEvent>;
    let command: ref<AIVehicleJoinTrafficCommand>;
    if !this.IsReady() { return false; };

    this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    this.activeJoinTrafficCommand = null;

    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleOnSplineCommand", false, true);

    driverReady = new AIEvent();
    driverReady.name = n"DriverReady";
    this.bus.QueueEvent(driverReady);

    command = new AIVehicleJoinTrafficCommand();
    command.needDriver = false;
    command.useKinematic = true;
    this.bus.GetAIComponent().SendCommand(command);
    this.activeJoinTrafficCommand = command;
    return true;
  }

  public func IsInTrafficLane() -> Bool {
    return this.IsReady() && this.bus.IsInTrafficLane();
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

'''
once(anchor, methods + anchor, "direct join methods")

old = '''        let exitSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 5.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingRetryCount = 0;
        if Equals(this.requestedStopId, 70) {
          this.bayParkingStage = 12;
          this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };'''
new = '''        let exitSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 5.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingRetryCount = 0;
        if Equals(this.requestedStopId, 70) {
          // r381a: H2 leaves the berth under the vanilla traffic rejoin command.
          // The validated arrival spline and stop position are untouched; the
          // departure spline is deliberately not started at all.
          this.bayParkingStage = 14;
          quests.SetFact(n"nctc_dev_join_pre_speed_mm", Cast<Int32>(AbsF(this.controller.GetCurrentSpeed()) * 1000.00));
          this.driveCommandSent = this.controller.JoinTrafficDirectFromBerth();
          quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
          quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 84 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.05);
          return;
        };'''
once(old, new, "H2 direct join departure")

anchor = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 13) {
      this.ScheduleDispatch(0.25);
      return;
    };'''
stage14 = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 14) {
      let joinedSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
      let inTrafficLane: Bool = this.controller.IsInTrafficLane();
      this.bayParkingRetryCount += 1;
      quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
      quests.SetFact(n"nctc_dev_bus_in_traffic_lane", inTrafficLane ? 1 : 0);
      quests.SetFact(n"nctc_dev_join_poll_count", this.bayParkingRetryCount);
      quests.SetFact(n"nctc_dev_join_speed_mm", Cast<Int32>(joinedSpeed * 1000.00));

      if inTrafficLane {
        this.bayParkingActive = false;
        this.bayParkingStage = 0;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = this.controller.DriveToTrafficAfterSpline(this.GetTrafficTarget(), 0.00, joinedSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 86 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };

      if this.controller.IsJoinTrafficCommandFailed() {
        // Deliberately do NOT fall back to the old r376f traffic handoff here.
        // A failed direct JoinTraffic must remain visible instead of hiding the
        // result by sending the bus toward the intersection with another command.
        this.PublishLoopDiagnostic(87, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };

      this.PublishLoopDiagnostic(85, this.requestedStopId);
      this.ScheduleDispatch(0.05);
      return;
    };

'''
once(anchor, stage14 + anchor, "stage14 direct join poll")
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
    '''    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",
    [75] = "route loop: r376b H2 native departure spline FAILED"
  }''',
    '''    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",
    [75] = "route loop: r376b H2 native departure spline FAILED",
    [84] = "route loop: r381a H2 direct vanilla JoinTraffic armed from berth",
    [85] = "route loop: r381a direct JoinTraffic active",
    [86] = "route loop: r381a traffic lane acquired -> normal route",
    [87] = "route loop: r381a direct JoinTraffic FAILED; holding for diagnosis"
  }''',
    "CET state labels",
)

conce(
    '''  if code == 48 or code == 49 or code == 54 then
    command_extra = command_extra''',
    '''  if code == 84 or code == 85 or code == 86 or code == 87 then
    local join_states = { [0] = "missing", [1] = "active", [2] = "success", [3] = "failed/cancelled" }
    command_extra = command_extra
      .. " joinState=" .. (join_states[fact(quests, "nctc_dev_join_traffic_state")] or "unknown")
      .. " inTrafficLane=" .. tostring(fact(quests, "nctc_dev_bus_in_traffic_lane"))
      .. " joinPoll=" .. tostring(fact(quests, "nctc_dev_join_poll_count"))
      .. " preSpeed=" .. string.format("%.2f", fact(quests, "nctc_dev_join_pre_speed_mm") / 1000.0)
      .. " joinSpeed=" .. string.format("%.2f", fact(quests, "nctc_dev_join_speed_mm") / 1000.0)
  end
  if code == 48 or code == 49 or code == 54 then
    command_extra = command_extra''',
    "CET direct join telemetry",
)

conce(
    'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 then',
    'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 or code == 84 or code == 85 or code == 86 or code == 87 then',
    "CET state list",
)

conce(
    '''  if revision == 37606 then
    log("NCTC runtime build=37606 r376f H2 final nose clearance")''',
    '''  if revision == 38101 then
    log("NCTC runtime build=38101 r381a H2 direct vanilla JoinTraffic from berth")
  elseif revision == 37606 then
    log("NCTC runtime build=37606 r376f H2 final nose clearance")''',
    "CET build revision",
)

cet.write_text(c)
