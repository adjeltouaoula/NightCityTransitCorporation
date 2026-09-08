// Minimal traffic-driving bridge used by NCTC when Auto Drive Enhanced is
// not installed. The accompanying vehicle behavior resource invokes these
// delegate methods. Keeping the original command contract also makes NCTC
// coexist with ADE: when ADE is present, its implementation owns the type and
// these fallback declarations are omitted at compile time.

@if(!ModuleExists("AutoDriveEnhanced"))
public class AIVehicleDriveToPointCommand extends AIVehicleDriveToPointAutonomousCommand {
  public let secureTimeOut: Float;
  public let useTraffic: Bool;
  public let speedInTraffic: Float;
  public let forceGreenLights: Bool;
  public let portals: ref<vehiclePortalsList>;
  public let trafficTryNeighborsForStart: Bool;
  public let trafficTryNeighborsForEnd: Bool;
}

@if(!ModuleExists("AutoDriveEnhanced"))
@addMethod(AIDriveCommandsDelegate)
public final func DoStartDriveToPoint(context: ScriptExecutionContext) -> Bool {
  let command = this.m_driveToPointAutonomousCommand as AIVehicleDriveToPointCommand;
  if !IsDefined(command) { return false; };
  this.targetPosition = command.targetPosition;
  this.secureTimeOut = command.secureTimeOut;
  this.useTraffic = command.useTraffic;
  this.speedInTraffic = command.speedInTraffic;
  this.forceGreenLights = command.forceGreenLights;
  this.portals = command.portals;
  this.trafficTryNeighborsForStart = command.trafficTryNeighborsForStart;
  this.trafficTryNeighborsForEnd = command.trafficTryNeighborsForEnd;
  return true;
}

@if(!ModuleExists("AutoDriveEnhanced"))
@addMethod(AIDriveCommandsDelegate)
public final func DoUpdateDriveToPoint(context: ScriptExecutionContext) -> Bool {
  return IsDefined(this.m_driveToPointAutonomousCommand);
}

@if(!ModuleExists("AutoDriveEnhanced"))
@addMethod(AIDriveCommandsDelegate)
public final static func DoEndDriveToPoint(context: ScriptExecutionContext) -> Bool {
  return true;
}

@if(!ModuleExists("AutoDriveEnhanced"))
@addMethod(AIDriveCommandsDelegate)
public final func DoStopDriveToPoint(context: ScriptExecutionContext) -> Bool {
  this.m_driveToPointAutonomousCommand = null;
  return true;
}
