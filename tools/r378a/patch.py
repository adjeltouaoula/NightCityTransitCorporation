from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, got {n}")
    return text.replace(old, new, 1)


transit = Path("source/redscript/NCTC/NCTCTransitSystem.reds")
s = transit.read_text()

s = replace_once(
    s,
    "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let driveGeneration: Int32;",
    "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let activeJoinTrafficCommand: ref<AIVehicleJoinTrafficCommand>;\n  private let driveGeneration: Int32;",
    "join command field",
)

s = replace_once(
    s,
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37606);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37801);',
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

new_handoff = '''  // r378a: r376f already gets the Mahir cleanly out of the bay. Do not ask a
  // long-distance DriveToPoint(useTraffic=true) command to discover a lane
  // immediately from that off-traffic spline. First use the game's dedicated
  // JoinTraffic command, exactly the command family used by Delamain to enter
  // free-roam traffic. Keep kinematic movement disabled for the passenger bus.
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

  // Once JoinTraffic has attached the bus to native traffic, replace that
  // command with the normal NCTC route command while preserving rolling speed.
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

s = replace_once(s, old_handoff, new_handoff, "spline handoff function")

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
          if this.bayParkingActive && Equals(this.bayParkingStage, 14) {
            quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
            quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);
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
        if !this.AdvanceToNextStop() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        this.legPolls = 0;
        this.bayParkingStage = 14;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = this.controller.JoinTrafficAfterSpline();
        quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
        quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);
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

    if this.bayParkingActive && Equals(this.bayParkingStage, 14) {
      this.bayParkingRetryCount += 1;
      quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
      quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);
      if this.controller.IsJoinTrafficCommandSuccessful()
        || (this.bayParkingRetryCount >= 25 && this.controller.IsInTrafficLane()) {
        let joinState: Int32 = this.controller.GetJoinTrafficCommandStatusCode();
        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
        quests.SetFact(n"nctc_dev_join_traffic_state", joinState);
        quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);
        this.bayParkingActive = false;
        this.bayParkingStage = 0;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = this.controller.DriveToTrafficAfterJoin(this.GetTrafficTarget(), 0.00, rollingSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 77 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsJoinTrafficCommandFailed() {
        this.bayParkingStage = 15;
        this.PublishLoopDiagnostic(78, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 15) {
      this.ScheduleDispatch(0.25);
      return;
    };'''

s = replace_once(s, old_stage, new_stage, "stage 12 handoff")
transit.write_text(s)

cet = Path("source/cet/nctc_survey/init.lua")
c = cet.read_text()

c = replace_once(
    c,
    '    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",\n    [75] = "route loop: r376b H2 native departure spline FAILED"',
    '    [74] = "route loop: r378a H2 spline exit -> native JoinTraffic armed",\n    [75] = "route loop: r376b H2 native departure spline FAILED",\n    [76] = "route loop: r378a native JoinTraffic active telemetry",\n    [77] = "route loop: r378a native JoinTraffic -> route handoff",\n    [78] = "route loop: r378a native JoinTraffic FAILED"',
    "diagnostic labels",
)

c = replace_once(
    c,
    "  if code == 48 or code == 49 or code == 54 then",
    '''  if code == 74 or code == 76 or code == 77 or code == 78 then
    local join_states = { [0] = "missing", [1] = "active", [2] = "success", [3] = "failed/cancelled" }
    command_extra = command_extra
      .. " joinState=" .. (join_states[fact(quests, "nctc_dev_join_traffic_state")] or "unknown")
      .. " inTrafficLane=" .. tostring(fact(quests, "nctc_dev_bus_in_traffic_lane"))
  end
  if code == 48 or code == 49 or code == 54 then''',
    "join diagnostic details",
)

c = replace_once(
    c,
    "or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 then",
    "or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 or code == 76 or code == 77 or code == 78 then",
    "detailed diagnostic list",
)

c = replace_once(
    c,
    '  if revision == 37606 then\n    log("NCTC runtime build=37606 r376f H2 final nose clearance")',
    '  if revision == 37801 then\n    log("NCTC runtime build=37801 r378a H2 native JoinTraffic handoff")\n  elseif revision == 37606 then\n    log("NCTC runtime build=37606 r376f H2 final nose clearance")',
    "build log",
)

cet.write_text(c)
