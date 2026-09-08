

@addMethod(AutodriveAndCinematicCameraContextDecisions)
protected func IsPassenger(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  let vehicle: wref<VehicleObject>;
  if this.GetVehicle(scriptInterface, vehicle) {
    let driver = VehicleComponent.GetDriverMounted(vehicle.GetGame(), vehicle.GetEntityID()) as ScriptedPuppet;
    return !IsDefined(driver) || !driver.IsPlayer();
  }
  return false;
}

@wrapMethod(VehicleAutodriveContextDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    return wrappedMethod(stateContext, scriptInterface) && !this.IsPassenger(stateContext, scriptInterface);
}

@wrapMethod(VehicleMountedWeaponsAutodriveContextDecisions)
protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    return wrappedMethod(stateContext, scriptInterface) && !this.IsPassenger(stateContext, scriptInterface);
}

public class VehicleAutodrivePassengerContextEvents extends VehicleAutodriveContextEvents {
}

public class VehicleAutodrivePassengerContextDecisions extends VehicleAutodriveContextDecisions {
  protected const func EnterCondition(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    let vehicle: wref<VehicleObject>;
    if this.GetVehicle(scriptInterface, vehicle) {
      return !vehicle.IsDelamainTaxi_ADE() && this.IsPassenger(stateContext, scriptInterface);
    }
    return false;
  }
}


@if(!ModuleExists("AutoDriveMod"))
// base\gameplay\ai\behaviors\vehicle\default_vehicle.behavior.
public class AIVehicleDriveToPointCommand extends AIVehicleDriveToPointAutonomousCommand {
    public let secureTimeOut: Float;
    public let useTraffic: Bool;
    public let speedInTraffic: Float;
    public let forceGreenLights: Bool;
    public let portals: ref<vehiclePortalsList>;
    public let trafficTryNeighborsForStart: Bool;
    public let trafficTryNeighborsForEnd: Bool;
}

@if(!ModuleExists("AutoDriveMod"))
@addMethod(AIDriveCommandsDelegate)
public final func DoStartDriveToPoint(context: ScriptExecutionContext) -> Bool {
    let cmd = this.m_driveToPointAutonomousCommand as AIVehicleDriveToPointCommand;
    this.targetPosition = cmd.targetPosition;

    this.secureTimeOut = cmd.secureTimeOut;
    this.useTraffic = cmd.useTraffic;
    this.speedInTraffic = cmd.speedInTraffic;
    this.forceGreenLights = cmd.forceGreenLights;
    this.portals = cmd.portals;
    this.trafficTryNeighborsForStart = cmd.trafficTryNeighborsForStart;
    this.trafficTryNeighborsForEnd = cmd.trafficTryNeighborsForEnd;

    return true;
}

@if(!ModuleExists("AutoDriveMod"))
@addMethod(AIDriveCommandsDelegate)
public final func DoUpdateDriveToPoint(context: ScriptExecutionContext) -> Bool {
    if !IsDefined(this.m_driveToPointAutonomousCommand) {
        return false;
    };
    return true;
}

@if(!ModuleExists("AutoDriveMod"))
@addMethod(AIDriveCommandsDelegate)
public final static func DoEndDriveToPoint(context: ScriptExecutionContext) -> Bool {
    return true;
}

@if(!ModuleExists("AutoDriveMod"))
@addMethod(AIDriveCommandsDelegate)
public final func DoStopDriveToPoint(context: ScriptExecutionContext) -> Bool {
    if IsDefined(this.m_driveToPointAutonomousCommand) {
        this.m_driveToPointAutonomousCommand = null;
    };
    return true;
}
