import NCTC.*

native func LogChannel(channel: CName, const text: script_ref<String>)

// Exact vehicle collision diagnostics. These hooks do not alter, consume, or
// suppress either event.

// This is the earliest script-visible event carrying the actual striking
// vehicle. Vanilla later builds Attacks.CarHitPlayer with the player as both
// source and instigator, which is why status-effect logs lose this carId.
@wrapMethod(PlayerPuppet)
protected cb func OnCarHitPlayer(evt: ref<OnCarHitPlayer>) -> Bool {
  let car: ref<VehicleObject>;
  let carID: String = "none";
  let carRecord: String = "none";
  let insideFact: Int32 = 0;
  let transit: ref<NCTCTransitSystem>;

  if IsDefined(evt) {
    carID = EntityID.ToDebugString(evt.carId);
    car = GameInstance.FindEntityByID(this.GetGame(), evt.carId) as VehicleObject;
    if IsDefined(car) {
      carRecord = TDBID.ToStringDEBUG(car.GetRecordID());
    };
    insideFact = GameInstance.GetQuestsSystem(this.GetGame()).GetFact(n"nctc_player_in_service_bus");
    LogChannel(n"DEBUG", s"[NCTC CarHit Redscript Pre] carId=\(carID) carResolved=\(IsDefined(car)) carRecord=\(carRecord) hitDirection=\(evt.hitDirection) separationImpulse=\(evt.seperationImpulse) playerPosition=\(this.GetWorldPosition()) insideFact=\(insideFact)");

    // This is deliberately before vanilla turns the collision into
    // Attacks.CarHitPlayer / VehicleKnockdown.  V is a passenger standing in
    // this exact NCTC bus, not a pedestrian hit by it.  Every other vehicle,
    // and V outside the cabin, still uses untouched vanilla collision.
    transit = NCTCTransitSystem.Get(this.GetGame());
    if Equals(insideFact, 1) && IsDefined(transit) && transit.IsActiveServiceBus(evt.carId) {
      LogChannel(n"DEBUG", s"[NCTC CarHit] consumed internal service-bus contact carId=\(carID)");
      return false;
    };
  };

  return wrappedMethod(evt);
}

@wrapMethod(ReactionManagerComponent)
protected cb func OnVehicleHit(evt: ref<gameVehicleHitEvent>) -> Bool {
  let owner: ref<ScriptedPuppet> = this.GetOwnerPuppet();
  let source: ref<GameObject>;
  let instigator: ref<GameObject>;
  let sourceID: String = "none";
  let instigatorID: String = "none";

  if IsDefined(owner) && owner.IsPlayer() && IsDefined(evt) && IsDefined(evt.attackData) {
    source = evt.attackData.GetSource();
    instigator = evt.attackData.GetInstigator();
    if IsDefined(source) { sourceID = EntityID.ToDebugString(source.GetEntityID()); };
    if IsDefined(instigator) { instigatorID = EntityID.ToDebugString(instigator.GetEntityID()); };
    LogChannel(n"DEBUG", s"[NCTC Collision] PLAYER VEHICLE HIT source=\(sourceID) instigator=\(instigatorID) vehicleVelocity=\(evt.vehicleVelocity) preyVelocity=\(evt.preyVelocity)");
  };

  return wrappedMethod(evt);
}

@wrapMethod(PlayerPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let mounted: ref<VehicleObject>;
  let effectID: TweakDBID;
  let mountedID: String = "none";

  if IsDefined(evt) && IsDefined(evt.staticData) {
    effectID = evt.staticData.GetID();
    if Equals(effectID, t"BaseStatusEffect.VehicleKnockdown") {
      mounted = this.GetMountedVehicle();
      if IsDefined(mounted) { mountedID = EntityID.ToDebugString(mounted.GetEntityID()); };
      LogChannel(n"DEBUG", s"[NCTC Collision] PLAYER VEHICLE KNOCKDOWN position=\(this.GetWorldPosition()) mounted=\(IsDefined(mounted)) mountedVehicle=\(mountedID)");
    };
  };

  return wrappedMethod(evt);
}
