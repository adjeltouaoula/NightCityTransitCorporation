from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)


transit_path = Path("source/redscript/NCTC/NCTCTransitSystem.reds")
s = transit_path.read_text()

s = replace_once(
    s,
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37601);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37607);',
    "runtime",
)

marker = "  // r374e: generation-safe traffic replacement, but unlike r372n the\n"
method = '''  // r377a: the departure spline has already completed successfully here,
  // so do not interrupt it again. Hand the measured rolling speed to the
  // native traffic navigator only after the spline has lane-locked the Mahir.
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
s = replace_once(s, marker, method + marker, "insert traffic-after-spline")

# r376a intentionally froze at H2 after proving arrival. r377a restores the
# dwell/departure path, keeps r376f bay geometry, then extends the departure
# spline through the surveyed post-H2 passage before traffic reacquisition.
hold = '''      if Equals(this.requestedStopId, 70) && this.HasServiceBay() && this.bayParkingWasEntered {
        this.ScheduleDispatch(0.25);
        return;
      };
'''
s = replace_once(s, hold, "", "remove r376a POC hold")

old_leave = '''      if leaveBayDirect {
        let exitSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 5.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingStage = 3;
        this.bayParkingRetryCount = 0;
        this.bayParkingRoadTarget = this.GetBayParkingRoadTarget();
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingRoadTarget, exitSpeed, 5.00);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 63 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
'''
new_leave = '''      if leaveBayDirect {
        let exitSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 5.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingRetryCount = 0;
        if Equals(this.requestedStopId, 70) {
          this.bayParkingStage = 12;
          this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };
        this.bayParkingStage = 3;
        this.bayParkingRoadTarget = this.GetBayParkingRoadTarget();
        this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingRoadTarget, exitSpeed, 5.00);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 63 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
'''
s = replace_once(s, old_leave, new_leave, "H2 departure arm")

old_tel = '''      if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
        this.PublishLoopDiagnostic(71, this.requestedStopId);
      } else {
        this.PublishRouteCommandTelemetry();
      };
'''
new_tel = '''      if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
        this.PublishLoopDiagnostic(71, this.requestedStopId);
      } else {
        if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
          this.PublishLoopDiagnostic(73, this.requestedStopId);
        } else {
          this.PublishRouteCommandTelemetry();
        };
      };
'''
s = replace_once(s, old_tel, new_tel, "departure telemetry")

stage11 = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 11) {
      this.ScheduleDispatch(0.25);
      return;
    };

'''
departure = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
      if this.controller.IsSplineCommandSuccessful() {
        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
        if !this.AdvanceToNextStop() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        // r377a: the authored H2 departure spline already crosses the first
        // passage after stop 70 and ends ~20 m down its outgoing lane. Consume
        // that passage before handing control to traffic, otherwise the runtime
        // would briefly issue a redundant command toward a waypoint behind us.
        if this.followingPassage && Equals(this.passageAfterStopId, 70) {
          if !this.AdvancePassageOrDestination() {
            this.PublishLoopDiagnostic(34, 0);
            this.ScheduleDispatch(1.00);
            return;
          };
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
    };

'''
s = replace_once(s, stage11, stage11 + departure, "departure state machine")
transit_path.write_text(s)

cet_path = Path("source/cet/nctc_survey/init.lua")
c = cet_path.read_text()
old_codes = '''    [68] = "route loop: r376a H2 native spline armed",
    [69] = "route loop: r376a H2 native spline reached path end",
    [70] = "route loop: r376a H2 native spline FAILED",
    [71] = "route loop: r376a H2 native spline active telemetry"
'''
new_codes = '''    [68] = "route loop: r376a H2 native spline armed",
    [69] = "route loop: r376a H2 native spline reached path end",
    [70] = "route loop: r376a H2 native spline FAILED",
    [71] = "route loop: r376a H2 native spline active telemetry",
    [72] = "route loop: r377a H2 lane-lock departure spline armed",
    [73] = "route loop: r377a H2 lane-lock departure spline active telemetry",
    [74] = "route loop: r377a H2 lane-locked spline exit -> native traffic handoff",
    [75] = "route loop: r377a H2 lane-lock departure spline FAILED"
'''
c = replace_once(c, old_codes, new_codes, "CET codes")

old_list = "or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 then"
new_list = "or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 then"
c = replace_once(c, old_list, new_list, "CET bay-code list")

old_build = '''  if revision == 37601 then
    log("NCTC runtime build=37601 r376a H2 native spline arrival POC")
'''
new_build = '''  if revision == 37607 then
    log("NCTC runtime build=37607 r377a H2 lane-locked handoff")
  elseif revision == 37601 then
    log("NCTC runtime build=37601 r376a H2 native spline arrival POC")
'''
c = replace_once(c, old_build, new_build, "CET build marker")
cet_path.write_text(c)

print("R377A_PATCH_OK")
