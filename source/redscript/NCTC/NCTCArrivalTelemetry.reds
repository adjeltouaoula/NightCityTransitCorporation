module NCTC

// Development-only observer for ADE's actual drive-command lifecycle. It does
// not alter a return value, route, state, or command; it only publishes facts
// consumed by the CET survey log when the owner is our tagged service bus.
public class NCTCArrivalTelemetry {
  public static func Publish(context: ScriptExecutionContext, eventCode: Int32, command: ref<AIVehicleDriveToPointCommand>) -> Void {
    let owner: ref<GameObject> = ScriptExecutionContext.GetOwner(context);
    let bus: ref<VehicleObject> = owner as VehicleObject;
    let quests: ref<QuestsSystem>;
    let position: Vector4;
    if !IsDefined(bus) || !bus.RecordHasTag(n"NCTCServiceBus") { return; };
    quests = GameInstance.GetQuestsSystem(bus.GetGame());
    if !IsDefined(quests) { return; };
    position = bus.GetWorldPosition();
    quests.SetFact(n"nctc_dev_native_command_event_code", eventCode);
    quests.SetFact(n"nctc_dev_native_command_x_mm", Cast<Int32>(position.X * 1000.00));
    quests.SetFact(n"nctc_dev_native_command_y_mm", Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(n"nctc_dev_native_command_z_mm", Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(n"nctc_dev_native_command_speed_mm", Cast<Int32>(AbsF(bus.GetCurrentSpeed()) * 1000.00));
    quests.SetFact(n"nctc_dev_native_command_has_object", IsDefined(command) ? 1 : 0);
    quests.SetFact(n"nctc_dev_native_command_state", IsDefined(command) && Equals(command.state, AICommandState.Success) ? 2 : (IsDefined(command) && (Equals(command.state, AICommandState.Failure) || Equals(command.state, AICommandState.Cancelled) || Equals(command.state, AICommandState.Interrupted)) ? 3 : 1));
    quests.SetFact(n"nctc_dev_native_command_event_id", quests.GetFact(n"nctc_dev_native_command_event_id") + 1);
  }
}

// These hooks observe ADE's own delegate methods. The vanilla NCTC traffic
// runtime provides its fallback methods via @addMethod, which cannot be a
// reliable @wrapMethod target in the same compilation set. Keep the ADE
// observer only when the ADE module actually owns those methods.
@if(ModuleExists("AutoDriveEnhanced"))
@wrapMethod(AIDriveCommandsDelegate)
public final func DoStartDriveToPoint(context: ScriptExecutionContext) -> Bool {
  let result: Bool = wrappedMethod(context);
  NCTCArrivalTelemetry.Publish(context, 1, this.m_driveToPointAutonomousCommand as AIVehicleDriveToPointCommand);
  return result;
}

@if(ModuleExists("AutoDriveEnhanced"))
@wrapMethod(AIDriveCommandsDelegate)
public final static func DoEndDriveToPoint(context: ScriptExecutionContext) -> Bool {
  let result: Bool = wrappedMethod(context);
  NCTCArrivalTelemetry.Publish(context, 2, null);
  return result;
}

@if(ModuleExists("AutoDriveEnhanced"))
@wrapMethod(AIDriveCommandsDelegate)
public final func DoStopDriveToPoint(context: ScriptExecutionContext) -> Bool {
  NCTCArrivalTelemetry.Publish(context, 3, this.m_driveToPointAutonomousCommand as AIVehicleDriveToPointCommand);
  return wrappedMethod(context);
}
