module NCTC

// Auto Drive Enhanced deliberately displays its hint for every passenger,
// even when its activation gate rejects the vehicle. NCTC service buses are
// autonomous public transport, so suppress that player-facing HUD affordance
// while retaining ADE's normal behaviour for every other vehicle.
@wrapMethod(AutoDriveController)
private final func ShouldInputHintBeVisible() -> Bool {
  let mountedVehicle: ref<VehicleObject>;
  let result: Bool = wrappedMethod();
  if IsDefined(this.m_player) {
    mountedVehicle = this.m_player.GetMountedVehicle();
    if IsDefined(mountedVehicle) && mountedVehicle.RecordHasTag(n"NCTCServiceBus") {
      return false;
    };
  };
  return result;
}
