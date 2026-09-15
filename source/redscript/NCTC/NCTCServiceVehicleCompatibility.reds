module NCTC

// NCTC service buses are public transport, never V's owned/driven vehicle.
// Keep the vanilla passenger mount semantics intact, then reassert only the
// persistent vehicle identity flags that external vehicle systems may inspect.
@wrapMethod(VehicleObject)
protected cb func OnMountingEvent(evt: ref<MountingEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let vehiclePS: ref<VehicleComponentPS>;

  if !this.RecordHasTag(n"NCTCServiceBus") {
    return result;
  };

  vehiclePS = this.GetVehiclePS();
  if IsDefined(vehiclePS) {
    vehiclePS.SetIsPlayerVehicle(false);
    vehiclePS.SetIsStolen(false);
  };

  return result;
}
