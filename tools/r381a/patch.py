from pathlib import Path
import sys

root = Path(sys.argv[1])
transit = root / "source/redscript/NCTC/NCTCTransitSystem.reds"
s = transit.read_text()

def once(old, new, name):
    global s
    if s.count(old) != 1:
        raise SystemExit(f"{name} anchor failed: {s.count(old)}")
    s = s.replace(old, new, 1)

once("  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let driveGeneration: Int32;", "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let activeJoinTrafficCommand: ref<AIVehicleJoinTrafficCommand>;\n  private let driveGeneration: Int32;", "join field")
once('SetFact(n"nctc_dev_build_revision", 37606);', 'SetFact(n"nctc_dev_build_revision", 38101);', "revision")

anchor = '''  // r376b: the departure spline has already completed successfully here,
  // so do not interrupt it again. Hand the measured rolling speed to the
  // normal traffic navigator through the established generation-safe pulse.
  public func DriveToTrafficAfterSpline(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {'''
methods = '''  public func JoinTrafficDirectFromBerth() -> Bool {
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
once(anchor, methods + anchor, "methods")

old = '''        if Equals(this.requestedStopId, 70) {
          this.bayParkingStage = 12;
          this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };'''
new = '''        if Equals(this.requestedStopId, 70) {
          this.bayParkingStage = 14;
          quests.SetFact(n"nctc_dev_join_pre_speed_mm", Cast<Int32>(AbsF(this.controller.GetCurrentSpeed()) * 1000.00));
          this.driveCommandSent = this.controller.JoinTrafficDirectFromBerth();
          quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
          quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 84 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.05);
          return;
        };'''
once(old, new, "departure")

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
        this.PublishLoopDiagnostic(87, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.PublishLoopDiagnostic(85, this.requestedStopId);
      this.ScheduleDispatch(0.05);
      return;
    };

'''
once(anchor, stage14 + anchor, "poll")
transit.write_text(s)

cet = root / "source/cet/nctc_survey/init.lua"
c = cet.read_text()
def c1(old, new, name):
    global c
    if c.count(old) != 1:
        raise SystemExit(f"{name} anchor failed: {c.count(old)}")
    c = c.replace(old, new, 1)

c1('''    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",
    [75] = "route loop: r376b H2 native departure spline FAILED"
  }''', '''    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",
    [75] = "route loop: r376b H2 native departure spline FAILED",
    [84] = "route loop: r381a direct JoinTraffic armed from berth",
    [85] = "route loop: r381a direct JoinTraffic active",
    [86] = "route loop: r381a traffic lane acquired -> normal route",
    [87] = "route loop: r381a direct JoinTraffic FAILED; holding"
  }''', "labels")
c1('''  if code == 48 or code == 49 or code == 54 then
    command_extra = command_extra''', '''  if code == 84 or code == 85 or code == 86 or code == 87 then
    local join_states = { [0] = "missing", [1] = "active", [2] = "success", [3] = "failed/cancelled" }
    command_extra = command_extra
      .. " joinState=" .. (join_states[fact(quests, "nctc_dev_join_traffic_state")] or "unknown")
      .. " inTrafficLane=" .. tostring(fact(quests, "nctc_dev_bus_in_traffic_lane"))
      .. " joinPoll=" .. tostring(fact(quests, "nctc_dev_join_poll_count"))
      .. " preSpeed=" .. string.format("%.2f", fact(quests, "nctc_dev_join_pre_speed_mm") / 1000.0)
      .. " joinSpeed=" .. string.format("%.2f", fact(quests, "nctc_dev_join_speed_mm") / 1000.0)
  end
  if code == 48 or code == 49 or code == 54 then
    command_extra = command_extra''', "telemetry")
c1('or code == 73 or code == 74 or code == 75 then', 'or code == 73 or code == 74 or code == 75 or code == 84 or code == 85 or code == 86 or code == 87 then', "state list")
c1('''  if revision == 37606 then
    log("NCTC runtime build=37606 r376f H2 final nose clearance")''', '''  if revision == 38101 then
    log("NCTC runtime build=38101 r381a H2 direct vanilla JoinTraffic from berth")
  elseif revision == 37606 then
    log("NCTC runtime build=37606 r376f H2 final nose clearance")''', "runtime")
cet.write_text(c)
