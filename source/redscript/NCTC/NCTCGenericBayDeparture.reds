module NCTC

// r383a: generic bay departure layer.
//
// The validated H2 architecture is now the departure policy for every authored
// two-point bay: wait for a safe roadside gap, hand the stopped Mahir to the
// native AIVehicleJoinTrafficCommand, then immediately continue toward the next
// NCTC route target once the vehicle is back in a traffic lane.
//
// This file deliberately does NOT change bay arrival yet. H2 therefore keeps
// the byte-identical r376a/r382h arrival spline while we isolate departure
// generalisation from spline generation.

@wrapMethod(NCTCServiceBusController)
public func Bind(bus: ref<VehicleObject>) -> Bool {
  let ok: Bool = wrappedMethod(bus);
  if ok && IsDefined(bus) {
    GameInstance.GetQuestsSystem(bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38301);
  };
  return ok;
}

// r382f-style rolling handoff after native JoinTraffic: do not send NoDriver
// after the traffic system has just acquired a lane. Keep only DriverReady and
// submit the successor command with the speed measured at lane acquisition.
@addMethod(NCTCServiceBusController)
public func DriveToTrafficAfterJoin(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {
  let callback: ref<NCTCDeferredDriveCommand>;
  let driverReady: ref<AIEvent>;
  let speedProfile: Int32;
  let speedLimit: Float;
  let generation: Int32;
  if !this.IsReady() { return false; };

  generation = this.NextDriveGeneration();
  this.previousRouteCommand = this.activeRouteCommand;
  this.activeRouteCommand = null;
  this.activeSplineCommand = null;
  this.activeJoinTrafficCommand = null;

  driverReady = new AIEvent();
  driverReady.name = n"DriverReady";
  this.bus.QueueEvent(driverReady);

  GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(
    n"nctc_dev_command_forced_start_speed_mm",
    Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00)
  );

  callback = new NCTCDeferredDriveCommand();
  speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
  callback.Configure(
    this.bus,
    this,
    target,
    minimumDistance,
    speedLimit,
    speedProfile,
    MaxF(startSpeed, 0.00),
    generation
  );
  GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.030, false);
  return true;
}

// Determine which side of the authored bay contains the road from the surveyed
// spawn position. This avoids assuming that every future bay is on the same
// world-space side of its road.
@addMethod(NCTCTransitSystem)
private func NCTCBayRoadSideSign() -> Float {
  let forward: Vector4 = this.GetBayForward();
  let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
  let fromEntryToSpawn: Vector4 = this.surveySpawn - this.GetBayEntryPoint();
  let lateral: Float = Vector4.Dot(fromEntryToSpawn, right);
  if lateral < -0.50 { return -1.00; };
  return 1.00;
}

// r382h geometry: inspect only the adjacent road lane, from 15 m behind the
// bus to 10 m ahead. Overlap() uses half extents, hence 12.5 m longitudinal
// half-length with a centre shifted 2.5 m rearward.
@addMethod(NCTCTransitSystem)
private func NCTCDepartureRoadsideBlocked() -> Bool {
  let spatial: ref<SpatialQueriesSystem>;
  let result: TraceResult;
  let dimensions: Vector4;
  let rotation: EulerAngles;
  let forward: Vector4;
  let right: Vector4;
  let center: Vector4;
  let sideSign: Float;
  let sideOffset: Float;
  let blocked: Bool;
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());

  if !this.HasServiceBay() || !IsDefined(this.controller) { return false; };
  spatial = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
  if !IsDefined(spatial) { return false; };

  forward = this.GetBayForward();
  if AbsF(forward.X) <= 0.01 && AbsF(forward.Y) <= 0.01 { return false; };
  right = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
  sideSign = this.NCTCBayRoadSideSign();

  // Bay centreline -> adjacent traffic-lane centre. Keep enough lateral offset
  // that the stopped Mahir cannot detect its own body.
  sideOffset = MaxF(this.GetBayWidth() * 0.50 + 2.75, 4.10);
  center = this.controller.GetWorldPosition() - forward * 2.50 + right * sideOffset * sideSign;
  center.Z += 1.25;
  dimensions = new Vector4(1.65, 12.50, 1.75, 0.00);
  rotation = Quaternion.ToEulerAngles(Quaternion.BuildFromDirectionVector(forward));
  blocked = spatial.Overlap(dimensions, center, rotation, n"Vehicle", result);

  if IsDefined(quests) {
    quests.SetFact(n"nctc_dev_generic_bay_road_side", sideSign > 0.00 ? 1 : -1);
    quests.SetFact(n"nctc_dev_generic_bay_departure_blocked", blocked ? 1 : 0);
    quests.SetFact(n"nctc_dev_generic_bay_guard_revision", 38301);
  };
  return blocked;
}

@wrapMethod(NCTCTransitSystem)
public func UpdateRequestedService() -> Void {
  let quests: ref<QuestsSystem>;
  let boarded: Bool;
  let joinedSpeed: Float;
  let inTrafficLane: Bool;

  quests = GameInstance.GetQuestsSystem(this.GetGameInstance());

  // Intercept the exact frame on which the stock loop would leave an authored
  // bay. Until dwell is complete, the original service loop remains fully in
  // charge of doors and passenger timing.
  if this.arrived && this.HasServiceBay() && !this.bayParkingBypass && this.bayParkingWasEntered
    && IsDefined(this.controller) && this.controller.IsReady() {
    boarded = this.controller.IsPlayerAboard()
      || Equals(quests.GetFact(n"nctc_passenger_departure_requested"), 1);

    if this.dwellPolls >= 8 && (boarded || this.dwellPolls >= 40) {
      // Require two consecutive clear samples before releasing the bus. A
      // transient single clear frame must not launch it into passing traffic.
      if this.NCTCDepartureRoadsideBlocked() {
        this.bayParkingRetryCount = 0;
        quests.SetFact(n"nctc_dev_generic_bay_clear_polls", 0);
        this.controller.ClosePassengerDoor();
        this.ScheduleDispatch(0.05);
        return;
      };

      this.bayParkingRetryCount += 1;
      quests.SetFact(n"nctc_dev_generic_bay_clear_polls", this.bayParkingRetryCount);
      if this.bayParkingRetryCount < 2 {
        this.controller.ClosePassengerDoor();
        this.ScheduleDispatch(0.05);
        return;
      };

      quests.SetFact(n"nctc_passenger_departure_requested", 0);
      quests.SetFact(n"nctc_service_bus_at_stop", 0);
      this.controller.ClosePassengerDoor();
      this.serviceStopId = 0;
      this.arrived = false;
      this.dwellPolls = 0;
      this.legPolls = 0;
      this.bayParkingActive = true;
      this.bayParkingStage = 14;
      this.bayParkingRetryCount = 0;
      quests.SetFact(n"nctc_dev_join_pre_speed_mm", Cast<Int32>(AbsF(this.controller.GetCurrentSpeed()) * 1000.00));
      this.driveCommandSent = this.controller.JoinTrafficDirectFromBerth();
      quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
      quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 90 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.05);
      return;
    };
  };

  // r382f handoff, generalized: as soon as vanilla JoinTraffic reports the bus
  // in a traffic lane, advance route state first and feed the next target
  // directly to the controller. This avoids the old second NoDriver cycle.
  if this.bayParkingActive && Equals(this.bayParkingStage, 14)
    && IsDefined(this.controller) && this.controller.IsReady() {
    joinedSpeed = AbsF(this.controller.GetCurrentSpeed());
    inTrafficLane = this.controller.IsInTrafficLane();
    quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
    quests.SetFact(n"nctc_dev_bus_in_traffic_lane", inTrafficLane ? 1 : 0);
    quests.SetFact(n"nctc_dev_join_speed_mm", Cast<Int32>(joinedSpeed * 1000.00));

    if inTrafficLane {
      if !this.AdvanceToNextStop() {
        this.PublishLoopDiagnostic(34, 0);
        this.ScheduleDispatch(1.00);
        return;
      };
      this.legPolls = 0;
      this.driveCommandSent = this.controller.DriveToTrafficAfterJoin(this.GetTrafficTarget(), 0.00, joinedSpeed);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 91 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.05);
      return;
    };
  };

  wrappedMethod();
}
