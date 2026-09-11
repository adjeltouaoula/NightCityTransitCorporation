from pathlib import Path

p = Path('source/redscript/NCTC/NCTCTransitSystem.reds')
s = p.read_text()

def once(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected 1 match, found {n}')
    s = s.replace(old, new, 1)

once('SetFact(n"nctc_dev_build_revision", 37502);', 'SetFact(n"nctc_dev_build_revision", 37601);', 'runtime')

marker = '\n\n// NCTC owns the native autonomous command lifecycle.'
spline_class = r'''

public class NCTCDeferredSplineDriveCommand extends DelayCallback {
  private let bus: wref<VehicleObject>;
  private let controller: wref<NCTCServiceBusController>;
  private let splinePath: String;
  private let startSpeed: Float;
  private let stopAtPathEnd: Bool;
  private let commandGeneration: Int32;

  public func Configure(bus: ref<VehicleObject>, controller: ref<NCTCServiceBusController>, splinePath: String, startSpeed: Float, stopAtPathEnd: Bool, commandGeneration: Int32) -> ref<NCTCDeferredSplineDriveCommand> {
    this.bus = bus;
    this.controller = controller;
    this.splinePath = splinePath;
    this.startSpeed = startSpeed;
    this.stopAtPathEnd = stopAtPathEnd;
    this.commandGeneration = commandGeneration;
    return this;
  }

  public func Call() -> Void {
    let command: ref<AIVehicleOnSplineCommand>;
    if !IsDefined(this.bus) || !this.bus.IsAttached() || !IsDefined(this.bus.GetAIComponent()) { return; };
    if IsDefined(this.controller) && !this.controller.IsDriveGenerationCurrent(this.commandGeneration) {
      this.controller.ReportStaleDriveCallback(this.commandGeneration);
      return;
    };
    command = new AIVehicleOnSplineCommand();
    command.splineRef = CreateNodeRef(this.splinePath);
    command.secureTimeOut = 120.00;
    command.driveBackwards = false;
    command.reverseSpline = false;
    command.startFromClosest = true;
    command.stopAtPathEnd = this.stopAtPathEnd;
    command.needDriver = false;
    command.useKinematic = false;
    if this.startSpeed > 0.50 { command.forcedStartSpeed = this.startSpeed; };
    this.bus.GetAIComponent().SendCommand(command);
    if IsDefined(this.controller) { this.controller.SetActiveSplineCommand(command, this.commandGeneration); };
  }
}
'''
once(marker, spline_class + marker, 'spline callback marker')

once('  private let previousRouteCommand: ref<AIVehicleDriveToPointCommand>;\n  private let driveGeneration: Int32;',
     '  private let previousRouteCommand: ref<AIVehicleDriveToPointCommand>;\n  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let driveGeneration: Int32;',
     'spline field')

adaptive = '  // Adaptive NCTC service speed. The game district supplies the zone profile\n'
spline_method = r'''  // r376a: H2 bay motion is a native continuous spline. Unlike
  // DriveToPoint, the intermediate curve points are geometry, not destinations.
  public func DriveOnBaySpline(splinePath: String, startSpeed: Float, stopAtPathEnd: Bool) -> Bool {
    let callback: ref<NCTCDeferredSplineDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let generation: Int32;
    if !this.IsReady() { return false; };
    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleOnSplineCommand", false, true);
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    callback = new NCTCDeferredSplineDriveCommand();
    callback.Configure(this.bus, this, splinePath, MaxF(startSpeed, 0.00), stopAtPathEnd, generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }

'''
once(adaptive, spline_method + adaptive, 'spline method')

accessor_marker = '  public func IsRouteCommandSuccessful() -> Bool {\n'
accessors = r'''  public func SetActiveSplineCommand(command: ref<AIVehicleOnSplineCommand>, generation: Int32) -> Void {
    if !this.IsDriveGenerationCurrent(generation) { return; };
    this.activeSplineCommand = command;
  }

  public func IsSplineCommandSuccessful() -> Bool {
    return IsDefined(this.activeSplineCommand) && Equals(this.activeSplineCommand.state, AICommandState.Success);
  }

  public func IsSplineCommandFailed() -> Bool {
    if !IsDefined(this.activeSplineCommand) { return false; };
    return Equals(this.activeSplineCommand.state, AICommandState.Failure)
      || Equals(this.activeSplineCommand.state, AICommandState.Cancelled)
      || Equals(this.activeSplineCommand.state, AICommandState.Interrupted);
  }

  public func GetSplineCommandStatusCode() -> Int32 {
    if !IsDefined(this.activeSplineCommand) { return 0; };
    if Equals(this.activeSplineCommand.state, AICommandState.Success) { return 2; };
    if this.IsSplineCommandFailed() { return 3; };
    return 1;
  }

'''
once(accessor_marker, accessors + accessor_marker, 'spline accessors')

old_cancel = '''  public func CancelTrafficRoute() -> Void {
    if this.IsReady() {
      this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    };
  }

  public func ArriveAtStop() -> Void {
    if !this.IsReady() { return; };
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
  }
'''
new_cancel = '''  public func CancelTrafficRoute() -> Void {
    if this.IsReady() {
      this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
      this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleOnSplineCommand", false, true);
    };
  }

  public func ArriveAtStop() -> Void {
    if !this.IsReady() { return; };
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleOnSplineCommand", false, true);
  }
'''
once(old_cancel, new_cancel, 'cleanup')

once('      this.controller.KeepPassengerDoorOpen();\n      boarded = this.controller.IsPlayerAboard()',
     '      this.controller.KeepPassengerDoorOpen();\n      if Equals(this.requestedStopId, 70) && this.HasServiceBay() && this.bayParkingWasEntered {\n        this.ScheduleDispatch(0.25);\n        return;\n      };\n      boarded = this.controller.IsPlayerAboard()',
     'H2 hold')

once('''    if this.telemetryPolls >= 10 {
      this.telemetryPolls = 0;
      this.PublishRouteCommandTelemetry();
    };''',
     '''    if this.telemetryPolls >= 10 {
      this.telemetryPolls = 0;
      if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
        this.PublishLoopDiagnostic(71, this.requestedStopId);
      } else {
        this.PublishRouteCommandTelemetry();
      };
    };''',
     'spline telemetry')

start = s.index('    // ENTRY: capture the real road centreline locally and issue ONE long direct')
end = s.index('    // Road-stop / occupied-bay fallback remains native traffic.', start)
fresh = r'''    // r376a H2-ONLY NATIVE SPLINE ARRIVAL POC.
    // All r375 DriveToPoint bay trajectory stages are intentionally removed.
    if !this.followingPassage && this.HasServiceBay() && !this.bayParkingActive
      && !this.bayParkingBypass && Equals(this.requestedStopId, this.serviceStopId)
      && Equals(this.requestedStopId, 70) {
      let entryLateral: Float;
      let entryLongitudinal: Float = this.GetBayEntryProgress(entryLateral);
      if entryLongitudinal > 0.50 && entryLongitudinal <= 24.00 && entryLateral <= 12.00 {
        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 6.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingStage = 10;
        this.bayParkingWasEntered = true;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/arrival_spline", entrySpeed, true);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 68 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
      if this.controller.IsSplineCommandSuccessful() {
        this.controller.ArriveAtStop();
        this.arrived = true;
        this.bayParkingActive = false;
        this.bayParkingStage = 0;
        this.driveCommandSent = false;
        this.dwellPolls = 0;
        quests.SetFact(n"nctc_service_bus_at_stop", 1);
        this.PublishLoopDiagnostic(69, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      if this.controller.IsSplineCommandFailed() {
        this.bayParkingStage = 11;
        this.PublishLoopDiagnostic(70, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 11) {
      this.ScheduleDispatch(0.25);
      return;
    };

'''
s = s[:start] + fresh + s[end:]
p.write_text(s)

q = Path('source/cet/nctc_survey/init.lua')
t = q.read_text()
old_codes = '''    [65] = "route loop: r375b entry retry",
    [66] = "route loop: r375b one-shot parking correction",
    [67] = "route loop: r375b exit retry"
'''
new_codes = '''    [65] = "route loop: r375b entry retry",
    [66] = "route loop: r375b one-shot parking correction",
    [67] = "route loop: r375b exit retry",
    [68] = "route loop: r376a H2 native spline armed",
    [69] = "route loop: r376a H2 native spline reached path end",
    [70] = "route loop: r376a H2 native spline FAILED",
    [71] = "route loop: r376a H2 native spline active telemetry"
'''
if t.count(old_codes) != 1: raise SystemExit('CET codes mismatch')
t = t.replace(old_codes, new_codes, 1)
old_extra = 'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 then'
new_extra = 'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 then'
if t.count(old_extra) != 1: raise SystemExit('CET extra mismatch')
t = t.replace(old_extra, new_extra, 1)
old_build = '  if revision == 37502 then\n    log("NCTC runtime build=37502 r375b early-progress parking + physical bay arrival")'
new_build = '  if revision == 37601 then\n    log("NCTC runtime build=37601 r376a H2 native spline arrival POC")\n  elseif revision == 37502 then\n    log("NCTC runtime build=37502 r375b early-progress parking + physical bay arrival")'
if t.count(old_build) != 1: raise SystemExit('CET build mismatch')
t = t.replace(old_build, new_build, 1)
q.write_text(t)
