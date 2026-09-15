module NCTC

// Compatibility probe for external anti-theft systems.
// NCTC service buses are public-transit service vehicles, not stealable cars.
// Anti-Theft Measures explicitly excludes quest/special vehicles, so mark only
// the active NCTC service-bus instance after the normal controller bind.
@wrapMethod(NCTCServiceBusController)
public func Bind(bus: ref<VehicleObject>) -> Bool {
  let result: Bool = wrappedMethod(bus);
  let vehiclePS: ref<VehicleComponentPS>;

  if !result || !IsDefined(bus) || !bus.RecordHasTag(n"NCTCServiceBus") {
    return result;
  };

  vehiclePS = bus.GetVehiclePS();
  if IsDefined(vehiclePS) {
    vehiclePS.SetIsMarkedAsQuest(true);
    GameInstance.GetQuestsSystem(bus.GetGame()).SetFact(n"nctc_dev_antitheft_quest_exclusion", 1);
  };

  return result;
}
