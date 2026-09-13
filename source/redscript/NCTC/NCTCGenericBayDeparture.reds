module NCTC

// r383c: conservative REDscript hotfix for generic authored bays.
//
// Keep the validated H2 architecture but remove two unnecessary sources of
// compiler/runtime ambiguity from r383b:
// - no diagnostic Bind() wrapper;
// - no dynamically constructed spline NodeRef string.
//
// The three currently generated bay assets are addressed explicitly. Future
// bays can be added to this mapping once the generic geometry is validated.

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

// Keep the forward half of the validated r382h departure guard: the game's own
// CrowdMember path query must also report ten metres clear. If the Mahir has no
// crowd component, fail open to the lateral road probe rather than deadlocking.
@addMethod(NCTCServiceBusController)
public func IsVanillaDeparturePathClear(distance: Float) -> Bool {
  let crowd: ref<CrowdMemberBaseComponent>;
  if !this.IsReady() { return false; };
  crowd = this.bus.GetCrowdMemberComponent();
  if !IsDefined(crowd) { return true; };
  return crowd.CheckEmptyPath(distance);
}

@addMethod(NCTCTransitSystem)
private final func NCTCBayArrivalSplinePath() -> String {
  if Equals(this.requestedStopId, 20) {
    return "$/nctc/bays/stop_20/arrival_spline";
  };
  if Equals(this.requestedStopId, 69) {
    return "$/nctc/bays/stop_69/arrival_spline";
  };
  if Equals(this.requestedStopId, 70) {
    return "$/nctc/bays/stop_70/arrival_spline";
  };
  return "";
}

// Determine which side of the authored bay contains the road from the surveyed
// spawn position. This avoids assuming that every future bay is on the same
// world-space side of its road.
@addMethod(NCTCTransitSystem)
private final func NCTCBayRoadSideSign() -> Float {
  let forward: Vector4 = this.GetBayForward();
  let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
  let fromEntryToSpawn: Vector4 = this.surveySpawn - this.GetBayEntryPoint();
  let lateral: Float = Vector4.Dot(fromEntryToSpawn, right);
  if lateral < -0.50 { return -1.00; };
  return 1.00;
}

// Full r382h departure gate, generalized from authored P1/P2 geometry:
// - vanilla CheckEmptyPath(10m) in front of the Mahir;
// - adjacent traffic lane from 15m behind to 10m ahead.
// Both must be clear for two consecutive samples before JoinTraffic starts.
@addMethod(NCTCTransitSystem)
private final func NCTCDepartureBlocked() -> Bool {
  let spatial: ref<SpatialQueriesSystem>;
  let result: TraceResult;
  let dimensions: Vector4;
  let rotation: EulerAngles;
  let forward: Vector4;
  let right: Vector4;
  let center: Vector4;
  let sideSign: Float = 1.00;
  let sideOffset: Float;
  let lateralBlocked: Bool = false;
  let forwardClear: Bool;
  let blocked: Bool;
  let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());

  if !this.HasServiceBay() || !IsDefined(this.controller) { return false; };

  forwardClear = this.controller.IsVanillaDeparturePathClear(10.00);
  sideSign = this.NCTCBayRoadSideSign();
  spatial = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());
  if IsDefined(spatial) {
    forward = this.GetBayForward();
    if AbsF(forward.X) > 0.01 || AbsF(forward.Y) > 0.01 {
      right = new Vector4(-forward.Y, forward.X, 0.00, 0.00);
      sideOffset = MaxF(this.GetBayWidth() * 0.50 + 2.75, 4.10);
      center = this.controller.GetWorldPosition() - forward * 2.50 + right * sideOffset * sideSign;
      center.Z += 1.25;
      dimensions = new Vector4(1.65, 12.50, 1.75, 0.00);
      rotation = Quaternion.ToEulerAngles(Quaternion.BuildFromDirectionVector(forward));
      lateralBlocked = spatial.Overlap(dimensions, center, rotation, n"Vehicle", result);
    };
  };

  blocked = !forwardClear || lateralBlocked;
  if IsDefined(quests) {
    quests.SetFact(n"nctc_dev_generic_bay_road_side", sideSign > 0.00 ? 1 : -1);
    quests.SetFact(n"nctc_dev_generic_bay_forward_clear", forwardClear ? 1 : 0);
    quests.SetFact(n"nctc_dev_generic_bay_lateral_blocked", lateralBlocked ? 1 : 0);
    quests.SetFact(n"nctc_dev_generic_bay_departure_blocked", blocked ? 1 : 0);
    quests.SetFact(n"nctc_dev_generic_bay_guard_revision", 38303);
  };
  return blocked;
}

@wrapMethod(NCTCTransitSystem)
public func UpdateRequestedService() -> Void {
  let quests: ref<QuestsSystem>;
  let boarded: Bool;
  let joinedSpeed: Float;
  let inTrafficLane: Bool;
  let splinePath: String;

  quests = GameInstance.GetQuestsSystem(this.GetGameInstance());

  // Generic replacement for the old stopId==70 arrival POC. Generated assets
  // use explicit paths here so REDscript never has to build a NodeRef string.
  if !this.followingPassage && this.HasServiceBay() && !this.bayParkingActive
    && !this.bayParkingBypass && Equals(this.requestedStopId, this.serviceStopId)
    && IsDefined(this.controller) && this.controller.IsReady() {
    splinePath = this.NCTCBayArrivalSplinePath();
    if NotEquals(splinePath, "") {
      let entryLateral: Float;
      let entryLongitudinal: Float = this.GetBayEntryProgress(entryLateral);
      if entryLongitudinal > 0.50 && entryLongitudinal <= 24.00 && entryLateral <= 12.00 {
        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 6.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingStage = 10;
        this.bayParkingWasEntered = true;
        this.bayParkingRetryCount = 0;
        quests.SetFact(n"nctc_dev_build_revision", 38303);
        quests.SetFact(n"nctc_dev_generic_bay_arrival_stop_id", this.requestedStopId);
        quests.SetFact(n"nctc_dev_generic_bay_arrival_revision", 38303);
        this.driveCommandSent = this.controller.DriveOnBaySpline(splinePath, entrySpeed, true);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 92 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
    };
  };

  // Intercept the exact frame on which the stock loop would leave an authored
  // bay. Until dwell is complete, the original service loop remains fully in
  // charge of doors and passenger timing.
  if this.arrived && this.HasServiceBay() && !this.bayParkingBypass && this.bayParkingWasEntered
    && IsDefined(this.controller) && this.controller.IsReady() {
    boarded = this.controller.IsPlayerAboard()
      || Equals(quests.GetFact(n"nctc_passenger_departure_requested"), 1);

    if this.dwellPolls >= 8 && (boarded || this.dwellPolls >= 40) {
      // Require two consecutive fully-clear samples. A transient single clear
      // frame must not launch the bus into passing or crossing traffic.
      if this.NCTCDepartureBlocked() {
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
