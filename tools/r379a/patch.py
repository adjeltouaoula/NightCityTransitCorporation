from pathlib import Path
import sys

root = Path(sys.argv[1])


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected 1 match, got {n}")
    return text.replace(old, new, 1)


transit = root / "source/redscript/NCTC/NCTCTransitSystem.reds"
s = transit.read_text()

s = replace_once(
    s,
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37606);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37901);',
    "runtime revision",
)

s = replace_once(
    s,
    '''    // These must remain false for the service bus. Enabling either one lets
    // the traffic controller snap the long Mahir to a neighboring lane when
    // a route command starts or ends, which can eject standing passengers.
    command.trafficTryNeighborsForStart = false;
    command.trafficTryNeighborsForEnd = false;''',
    '''    // Keep neighbor snapping disabled for the service bus: on the long Mahir
    // it can visibly teleport the vehicle sideways, which is not acceptable RP.
    command.trafficTryNeighborsForStart = false;
    command.trafficTryNeighborsForEnd = false;''',
    "neighbor-snap comment",
)

anchor = '''  public func DistanceToPlayer() -> Float {
    let player: ref<PlayerPuppet>;
    if !this.IsReady() { return 0.00; };
    player = GetPlayer(this.bus.GetGame());
    return IsDefined(player) ? Vector4.Distance(player.GetWorldPosition(), this.bus.GetWorldPosition()) : 0.00;
  }
'''
addition = anchor + '''
  // r379a: vanilla TrafficSystem query used as a yield gate before an off-lane
  // bay departure. The query entity is the bus itself, so the engine excludes
  // it while returning nearby crowd-traffic entities inside this road corridor.
  public func CountTrafficVehiclesInDepartureCorridor(forward: Vector4, rearDistance: Float, corridorDepth: Float, corridorWidth: Float) -> Int32 {
    let traffic: ref<TrafficSystem>;
    let entities: array<wref<Entity>>;
    let queryBoxPoints: array<Vector4>;
    let direction: Vector4;
    let right: Vector4;
    let origin: Vector4;
    let vehicle: wref<VehicleObject>;
    let i: Int32 = 0;
    let vehicleCount: Int32 = 0;
    if !this.IsReady() { return 0; };
    direction = Vector4.Normalize2D(forward);
    if AbsF(direction.X) <= 0.01 && AbsF(direction.Y) <= 0.01 { return 0; };
    right = new Vector4(-direction.Y, direction.X, 0.00, 0.00);
    origin = this.bus.GetWorldPosition() - direction * MaxF(rearDistance, 0.00);
    traffic = GameInstance.GetTrafficSystem(this.bus.GetGame());
    if !IsDefined(traffic) { return 0; };
    ArrayPush(queryBoxPoints, origin + new Vector4(0.00, 0.00, -1.00, 0.00));
    ArrayPush(queryBoxPoints, origin + direction * MaxF(corridorDepth, 1.00) + new Vector4(0.00, 0.00, 3.00, 0.00));
    ArrayPush(queryBoxPoints, origin + right * MaxF(corridorWidth * 0.50, 1.00));
    ArrayPush(queryBoxPoints, origin - right * MaxF(corridorWidth * 0.50, 1.00));
    traffic.FindEntitiesNearPlane(this.bus, queryBoxPoints, origin, right, MaxF(corridorWidth * 0.50, 1.00), 32, entities);
    while i < ArraySize(entities) {
      vehicle = entities[i] as VehicleObject;
      if IsDefined(vehicle) && !Equals(vehicle.GetEntityID(), this.bus.GetEntityID()) {
        vehicleCount += 1;
      };
      i += 1;
    };
    return vehicleCount;
  }
'''
s = replace_once(s, anchor, addition, "traffic corridor method")

old_departure = '''        if Equals(this.requestedStopId, 70) {
          this.bayParkingStage = 12;
          this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };'''
new_departure = '''        if Equals(this.requestedStopId, 70) {
          // r379a: do not launch the departure spline into live traffic. Hold the
          // bus in the bay until the native TrafficSystem corridor is clear.
          this.bayParkingStage = 14;
          this.driveCommandSent = true;
          quests.SetFact(n"nctc_dev_exit_traffic_count", 0);
          quests.SetFact(n"nctc_dev_exit_clear_polls", 0);
          this.PublishLoopDiagnostic(76, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };'''
s = replace_once(s, old_departure, new_departure, "H2 departure gate")

old_telemetry = '''      if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
        this.PublishLoopDiagnostic(71, this.requestedStopId);
      } else {
        if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
          this.PublishLoopDiagnostic(73, this.requestedStopId);
        } else {
          this.PublishRouteCommandTelemetry();
        };
      };'''
new_telemetry = '''      if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
        this.PublishLoopDiagnostic(71, this.requestedStopId);
      } else {
        if this.bayParkingActive && Equals(this.bayParkingStage, 14) {
          this.PublishLoopDiagnostic(79, this.requestedStopId);
        } else {
          if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
            this.PublishLoopDiagnostic(73, this.requestedStopId);
          } else {
            this.PublishRouteCommandTelemetry();
          };
        };
      };'''
s = replace_once(s, old_telemetry, new_telemetry, "yield telemetry")

stage12 = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
      if this.controller.IsSplineCommandSuccessful() {'''
stage14 = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 14) {
      let trafficCount: Int32 = this.controller.CountTrafficVehiclesInDepartureCorridor(this.GetBayForward(), 12.00, 80.00, 16.00);
      quests.SetFact(n"nctc_dev_exit_traffic_count", trafficCount);
      if trafficCount > 0 {
        this.bayParkingRetryCount = 0;
        quests.SetFact(n"nctc_dev_exit_clear_polls", 0);
        this.PublishLoopDiagnostic(77, this.requestedStopId);
        this.ScheduleDispatch(0.25);
        return;
      };
      this.bayParkingRetryCount += 1;
      quests.SetFact(n"nctc_dev_exit_clear_polls", this.bayParkingRetryCount);
      // Require a short stable gap rather than reacting to one empty frame.
      if this.bayParkingRetryCount < 3 {
        this.ScheduleDispatch(0.25);
        return;
      };
      this.bayParkingRetryCount = 0;
      this.bayParkingStage = 12;
      // Same validated r376f departure spline geometry. Only the manoeuvre pace
      // changes: low initial speed and braking to the spline end before handoff.
      this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", 1.25, true);
      this.PublishLoopDiagnostic(this.driveCommandSent ? 78 : 33, this.requestedStopId);
      this.ScheduleDispatch(0.10);
      return;
    };

''' + stage12
s = replace_once(s, stage12, stage14, "stage14 yield gate")
transit.write_text(s)

cet = root / "source/cet/nctc_survey/init.lua"
c = cet.read_text()
c = replace_once(
    c,
    '''    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",
    [75] = "route loop: r376b H2 native departure spline FAILED"''',
    '''    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",
    [75] = "route loop: r376b H2 native departure spline FAILED",
    [76] = "route loop: r379a H2 yield gate armed",
    [77] = "route loop: r379a H2 yield: traffic vehicle present",
    [78] = "route loop: r379a H2 clear gap -> slow departure spline armed",
    [79] = "route loop: r379a H2 yield gate telemetry"''',
    "CET states",
)
c = replace_once(
    c,
    '''  local command_extra = ""
  if code == 29 or code == 31 or code == 32 or code == 41 or code == 46 then''',
    '''  local command_extra = ""
  if code == 76 or code == 77 or code == 78 or code == 79 then
    command_extra = " trafficVehicles=" .. tostring(fact(quests, "nctc_dev_exit_traffic_count"))
      .. " clearPolls=" .. tostring(fact(quests, "nctc_dev_exit_clear_polls"))
  end
  if code == 29 or code == 31 or code == 32 or code == 41 or code == 46 then''',
    "CET yield extras",
)
c = replace_once(
    c,
    '''  if revision == 37606 then
    log("NCTC runtime build=37606 r376f H2 final nose clearance")''',
    '''  if revision == 37901 then
    log("NCTC runtime build=37901 r379a H2 yield-before-departure POC")
  elseif revision == 37606 then
    log("NCTC runtime build=37606 r376f H2 final nose clearance")''',
    "CET runtime",
)
cet.write_text(c)
