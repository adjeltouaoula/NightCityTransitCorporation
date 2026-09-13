from pathlib import Path
import sys

root = Path(sys.argv[1])
transit = root / "source/redscript/NCTC/NCTCTransitSystem.reds"
s = transit.read_text()

def once(old, new, name):
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"{name} anchor failed: {n}")
    s = s.replace(old, new, 1)

once('SetFact(n"nctc_dev_build_revision", 38101);', 'SetFact(n"nctc_dev_build_revision", 38102);', 'revision')

anchor = '''  // Native physics overlap is authoritative for bay occupancy. TargetingSystem\n  // does not reliably enumerate parked traffic vehicles.\n  private func IsBayOccupiedByVehicle() -> Bool {'''
insert = '''  // r381b: short vehicle-only merge-gap probe around the lane(s) immediately\n  // beside the stopped Mahir. Boxes are offset laterally so the service bus\n  // cannot detect itself. This gate only decides when JoinTraffic may START;\n  // it never changes the validated r381a trajectory.\n  private func IsDepartureMergeVehicleBlocked() -> Bool {\n    let spatial: ref<SpatialQueriesSystem>;\n    let leftResult: TraceResult;\n    let rightResult: TraceResult;\n    let dimensions: Vector4;\n    let rotation: EulerAngles;\n    let forward: Vector4;\n    let right: Vector4;\n    let center: Vector4;\n    let sideOffset: Float;\n    let leftBlocked: Bool;\n    let rightBlocked: Bool;\n    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());\n    if !IsDefined(this.controller) { return false; };\n    spatial = GameInstance.GetSpatialQueriesSystem(this.GetGameInstance());\n    if !IsDefined(spatial) { return false; };\n    forward = this.GetBayForward();\n    if AbsF(forward.X) <= 0.01 && AbsF(forward.Y) <= 0.01 { return false; };\n    right = new Vector4(-forward.Y, forward.X, 0.00, 0.00);\n    sideOffset = MaxF(this.GetBayWidth() * 0.50 + 2.25, 3.60);\n    // Half extents: ~3.0 m lane width x 20 m longitudinal gap.\n    // Center 2 m behind the bus: covers roughly 12 m behind / 8 m ahead.\n    dimensions = new Vector4(1.50, 10.00, 1.75, 0.00);\n    center = this.controller.GetWorldPosition() - forward * 2.00;\n    center.Z += 1.25;\n    rotation = Quaternion.ToEulerAngles(Quaternion.BuildFromDirectionVector(forward));\n    leftBlocked = spatial.Overlap(dimensions, center - right * sideOffset, rotation, n"Vehicle", leftResult);\n    rightBlocked = spatial.Overlap(dimensions, center + right * sideOffset, rotation, n"Vehicle", rightResult);\n    if IsDefined(quests) {\n      quests.SetFact(n"nctc_dev_merge_left_vehicle", leftBlocked ? 1 : 0);\n      quests.SetFact(n"nctc_dev_merge_right_vehicle", rightBlocked ? 1 : 0);\n      quests.SetFact(n"nctc_dev_merge_vehicle_blocked", leftBlocked || rightBlocked ? 1 : 0);\n    };\n    return leftBlocked || rightBlocked;\n  }\n\n''' + anchor
once(anchor, insert, 'merge probe')

old = '''        if Equals(this.requestedStopId, 70) {\n          this.bayParkingStage = 14;\n          quests.SetFact(n"nctc_dev_join_pre_speed_mm", Cast<Int32>(AbsF(this.controller.GetCurrentSpeed()) * 1000.00));\n          this.driveCommandSent = this.controller.JoinTrafficDirectFromBerth();\n          quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());\n          quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 84 : 33, this.requestedStopId);\n          this.ScheduleDispatch(0.05);\n          return;\n        };'''
new = '''        if Equals(this.requestedStopId, 70) {\n          if this.IsDepartureMergeVehicleBlocked() {\n            this.bayParkingStage = 15;\n            this.driveCommandSent = true;\n            this.PublishLoopDiagnostic(88, this.requestedStopId);\n            this.ScheduleDispatch(0.10);\n            return;\n          };\n          this.bayParkingStage = 14;\n          quests.SetFact(n"nctc_dev_join_pre_speed_mm", Cast<Int32>(AbsF(this.controller.GetCurrentSpeed()) * 1000.00));\n          this.driveCommandSent = this.controller.JoinTrafficDirectFromBerth();\n          quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());\n          quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 84 : 33, this.requestedStopId);\n          this.ScheduleDispatch(0.05);\n          return;\n        };'''
once(old, new, 'departure gate')

anchor = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 14) {'''
wait = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 15) {\n      if this.IsDepartureMergeVehicleBlocked() {\n        this.bayParkingRetryCount = 0;\n        quests.SetFact(n"nctc_dev_merge_clear_polls", 0);\n        this.PublishLoopDiagnostic(88, this.requestedStopId);\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n      this.bayParkingRetryCount += 1;\n      quests.SetFact(n"nctc_dev_merge_clear_polls", this.bayParkingRetryCount);\n      if this.bayParkingRetryCount < 3 {\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n      this.bayParkingRetryCount = 0;\n      this.bayParkingStage = 14;\n      quests.SetFact(n"nctc_dev_join_pre_speed_mm", Cast<Int32>(AbsF(this.controller.GetCurrentSpeed()) * 1000.00));\n      this.driveCommandSent = this.controller.JoinTrafficDirectFromBerth();\n      quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());\n      quests.SetFact(n"nctc_dev_bus_in_traffic_lane", this.controller.IsInTrafficLane() ? 1 : 0);\n      this.PublishLoopDiagnostic(this.driveCommandSent ? 89 : 33, this.requestedStopId);\n      this.ScheduleDispatch(0.05);\n      return;\n    };\n\n''' + anchor
once(anchor, wait, 'wait stage')

transit.write_text(s)

cet = root / "source/cet/nctc_survey/init.lua"
c = cet.read_text()
c = c.replace('NCTC runtime build=38101 r381a H2 direct vanilla JoinTraffic POC', 'NCTC runtime build=38102 r381b H2 direct JoinTraffic + vehicle gap')
# labels are optional telemetry; keep the patch robust if formatting differs.
marker = '[87] = "route loop: r381a JoinTraffic failed - hold"'
if marker in c:
    c = c.replace(marker, marker + ',\n    [88] = "route loop: r381b merge gap blocked by vehicle",\n    [89] = "route loop: r381b merge gap clear -> JoinTraffic"', 1)
cet.write_text(c)
