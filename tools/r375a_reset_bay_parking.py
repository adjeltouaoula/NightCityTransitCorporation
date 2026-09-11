from pathlib import Path
import re

p = Path('source/redscript/NCTC/NCTCTransitSystem.reds')
s = p.read_text(encoding='utf-8')

# 1) Direct bay command: make speed explicit. The fresh controller issues very
# few commands, each with a clear role (entry ray / stop / exit ray).
s = s.replace(
'''  private let startSpeed: Float;\n  private let commandGeneration: Int32;\n\n  public func Configure(bus: ref<VehicleObject>, controller: ref<NCTCServiceBusController>, target: Vector4, startSpeed: Float, commandGeneration: Int32) -> ref<NCTCDeferredBerthDriveCommand> {\n    this.bus = bus;\n    this.controller = controller;\n    this.target = target;\n    this.startSpeed = startSpeed;\n    this.commandGeneration = commandGeneration;''',
'''  private let startSpeed: Float;\n  private let maxSpeed: Float;\n  private let commandGeneration: Int32;\n\n  public func Configure(bus: ref<VehicleObject>, controller: ref<NCTCServiceBusController>, target: Vector4, startSpeed: Float, maxSpeed: Float, commandGeneration: Int32) -> ref<NCTCDeferredBerthDriveCommand> {\n    this.bus = bus;\n    this.controller = controller;\n    this.target = target;\n    this.startSpeed = startSpeed;\n    this.maxSpeed = maxSpeed;\n    this.commandGeneration = commandGeneration;''')
s = s.replace('    command.maxSpeed = 7.00;\n    command.minSpeed = 0.00;', '    command.maxSpeed = ClampF(this.maxSpeed, 1.00, 7.00);\n    command.minSpeed = 0.00;', 1)
s = s.replace(
'''  public func DriveToBerthDirect(target: Vector4, startSpeed: Float) -> Bool {''',
'''  public func DriveToBerthDirect(target: Vector4, startSpeed: Float, maxSpeed: Float) -> Bool {''')
s = s.replace(
'''    callback.Configure(this.bus, this, target, MaxF(startSpeed, 0.00), generation);''',
'''    callback.Configure(this.bus, this, target, MaxF(startSpeed, 0.00), maxSpeed, generation);''')

# 2) Throw away the accumulated r374 bay state. Keep occupancy as a separate,
# validated concern; parking state is intentionally tiny.
fields_pat = re.compile(r'''  private let berthManeuverActive: Bool;.*?  private let departureStallPolls: Int32;\n''', re.S)
fields_new = '''  // r375a: fresh bay-parking state. No r374 stage/watchdog/merge state survives.\n  // 0=inactive, 1=entry ray, 2=final stop, 3=exit ray.\n  private let bayParkingActive: Bool;\n  private let bayParkingStage: Int32;\n  private let bayParkingWasEntered: Bool;\n  private let bayParkingBypass: Bool;\n  private let bayParkingRoadLateral: Float;\n  private let bayParkingRetryCount: Int32;\n  private let bayParkingEntryTarget: Vector4;\n  private let bayParkingRoadTarget: Vector4;\n'''
s, n = fields_pat.subn(fields_new, s, count=1)
assert n == 1, 'fields block not replaced'

# 3) Replace all old bay trajectory helpers with four pieces of geometry.
helpers_pat = re.compile(r'''  // r374k: keep the successful early-nose entry,.*?  // Native physics overlap is authoritative for bay occupancy\.''', re.S)
helpers_new = '''  private func GetBayWidth() -> Float {\n    return this.hasSurveyBayWidth ? ClampF(this.surveyBayWidth, 2.20, 3.60) : 2.90;\n  }\n\n  // Signed progress from P1 along the bay centreline. Lateral is signed and\n  // measured in the bay frame; width is only a tolerance, never steering amplitude.\n  private func GetBayProgress(out lateral: Float) -> Float {\n    let forward: Vector4 = this.GetBayForward();\n    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);\n    let delta: Vector4 = this.controller.GetWorldPosition() - this.GetBayEntryPoint();\n    lateral = Vector4.Dot(delta, right);\n    return Vector4.Dot(delta, forward);\n  }\n\n  // Positive means P1 is still ahead of the bus.\n  private func GetBayEntryProgress(out lateral: Float) -> Float {\n    let forward: Vector4 = this.GetBayForward();\n    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);\n    let delta: Vector4 = this.GetBayEntryPoint() - this.controller.GetWorldPosition();\n    lateral = AbsF(Vector4.Dot(delta, right));\n    return Vector4.Dot(delta, forward);\n  }\n\n  // One long ray through the bay. P1 is never a destination, so the native\n  // point driver has no reason to brake at the mouth.\n  private func GetBayParkingEntryTarget() -> Vector4 {\n    return this.GetBayExitPoint() + this.GetBayForward() * 12.00;\n  }\n\n  // Rejoin the exact road line captured locally before P1. No guessed lane\n  // width and no overshoot beyond the measured bay axis.\n  private func GetBayParkingRoadTarget() -> Vector4 {\n    let forward: Vector4 = this.GetBayForward();\n    let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);\n    let lead: Float = ClampF(AbsF(this.bayParkingRoadLateral) * 3.50, 12.00, 18.00);\n    return this.GetBayExitPoint() + forward * lead + right * this.bayParkingRoadLateral;\n  }\n\n  // Native physics overlap is authoritative for bay occupancy.'''
s, n = helpers_pat.subn(helpers_new, s, count=1)
assert n == 1, 'helpers block not replaced'

# 4) Delete all r374 departure/approach helper machinery.
s, n = re.subn(r'''\n  // r374v: start the nose toward the exit.*?  // Positive longitudinal means the real berth is still ahead of the bus\.''',
'''\n  // Positive longitudinal means the real berth is still ahead of the bus.''', s, count=1, flags=re.S)
assert n == 1, 'old departure helpers not removed'

# 5) Replace old active-target dispatcher.
s, n = re.subn(r'''  private func GetActiveBerthTarget\(\) -> Vector4 \{.*?\n  \}\n\n  // The native Mahir controller''',
'''  private func GetBayParkingActiveTarget() -> Vector4 {\n    if Equals(this.bayParkingStage, 1) { return this.bayParkingEntryTarget; };\n    if Equals(this.bayParkingStage, 2) { return this.GetServiceBerth(); };\n    if Equals(this.bayParkingStage, 3) { return this.bayParkingRoadTarget; };\n    return this.GetServiceBerth();\n  }\n\n  // The native Mahir controller''', s, count=1, flags=re.S)
assert n == 1, 'active target dispatcher not replaced'

# 6) Diagnostics: preserve fact names for CET compatibility but feed only new state.
s = s.replace('let berthActiveTarget: Vector4 = this.GetActiveBerthTarget();', 'let berthActiveTarget: Vector4 = this.GetBayParkingActiveTarget();')
s = s.replace('this.berthManeuverStage', 'this.bayParkingStage')
s = s.replace('this.berthManeuverActive', 'this.bayParkingActive')
s = s.replace('this.berthWasEntered', 'this.bayParkingWasEntered')
s = s.replace('this.berthBypassActive', 'this.bayParkingBypass')
s = s.replace('quests.SetFact(n"nctc_dev_loop_berth_merge_lateral_mm", Cast<Int32>(this.berthMergeSignedLateral * 1000.00));', 'quests.SetFact(n"nctc_dev_loop_berth_merge_lateral_mm", Cast<Int32>(this.bayParkingRoadLateral * 1000.00));')
s = s.replace('quests.SetFact(n"nctc_dev_loop_berth_gate_road_lateral_mm", Cast<Int32>(this.berthGateRoadSignedLateral * 1000.00));', 'quests.SetFact(n"nctc_dev_loop_berth_gate_road_lateral_mm", 0);')

# 7) Clean reset assignments left from r374.
for old in [
    '    this.berthMergeSignedLateral = 0.00;\n',
    '    this.berthGateRoadSignedLateral = 0.00;\n',
    '    this.departureManeuverActive = false;\n',
    '    this.departureCurveStage = 0;\n',
    '    this.departureStallPolls = 0;\n',
    '    this.approachSlowdownApplied = false;\n',
]:
    s = s.replace(old, '')
# Add fresh state resets immediately after bypass reset wherever it occurs.
s = s.replace('    this.bayParkingBypass = false;\n', '    this.bayParkingBypass = false;\n    this.bayParkingRoadLateral = 0.00;\n    this.bayParkingRetryCount = 0;\n    this.bayParkingEntryTarget = new Vector4(0.00, 0.00, 0.00, 0.00);\n    this.bayParkingRoadTarget = new Vector4(0.00, 0.00, 0.00, 0.00);\n')

# 8) Fresh departure from an actual parked stop. Crucially, keep the OLD stop's
# bay geometry until the bus has physically rejoined the road; only then advance.
arrived_pat = re.compile(r'''      let leaveBayDirect: Bool = .*?      return;\n    \};\n\n    if !this\.driveCommandSent \{''', re.S)
arrived_new = '''      let leaveBayDirect: Bool = this.HasServiceBay() && !this.bayParkingBypass && this.bayParkingWasEntered;\n      this.serviceStopId = 0;\n      this.arrived = false;\n      this.dwellPolls = 0;\n      this.legPolls = 0;\n      if leaveBayDirect {\n        let exitSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 5.00), 2.00);\n        this.bayParkingActive = true;\n        this.bayParkingStage = 3;\n        this.bayParkingRetryCount = 0;\n        this.bayParkingRoadTarget = this.GetBayParkingRoadTarget();\n        this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingRoadTarget, exitSpeed, 5.00);\n        this.PublishLoopDiagnostic(this.driveCommandSent ? 63 : 33, this.requestedStopId);\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n      if !this.AdvanceToNextStop() {\n        this.PublishLoopDiagnostic(34, 0);\n        this.ScheduleDispatch(1.00);\n        return;\n      };\n      this.driveCommandSent = this.controller.DriveToTraffic(this.GetTrafficTarget(), 0.00);\n      this.PublishLoopDiagnostic(this.driveCommandSent ? 49 : 33, this.requestedStopId);\n      this.ScheduleDispatch(0.25);\n      return;\n    };\n\n    if !this.driveCommandSent {'''
s, n = arrived_pat.subn(arrived_new, s, count=1)
assert n == 1, 'arrived departure block not replaced'

# 9) Remove old dedicated departure state loop completely.
s, n = re.subn(r'''\n    if this\.departureManeuverActive \{.*?\n    \};\n\n    this\.legPolls \+= 1;''', '\n    this.legPolls += 1;', s, count=1, flags=re.S)
assert n == 1, 'old departure loop not removed'

# 10) Replace the entire r374 occupancy+trajectory state machine with fresh parking.
parking_pat = re.compile(r'''    // r374r: native physics overlap is the source of truth for occupied bays\..*?    // r374m: keep the single corridor command alive through arrival\.''', re.S)
parking_new = '''    // r375a BAY RESET. Occupancy remains the validated native overlap probe,\n    // but all trajectory logic below is new and intentionally minimal.\n    if !this.followingPassage && this.HasServiceBay() && !this.bayParkingActive && !this.bayParkingBypass\n      && Equals(this.requestedStopId, this.serviceStopId) {\n      let bayEntryDistance: Float = Vector4.Distance(this.controller.GetWorldPosition(), this.GetBayEntryPoint());\n      if bayEntryDistance <= 85.00 && bayEntryDistance >= 18.00 {\n        let bayOccupied: Bool = this.IsBayOccupiedByVehicle();\n        quests.SetFact(n"nctc_dev_berth_occupancy_stop_id", this.requestedStopId);\n        quests.SetFact(n"nctc_dev_berth_occupied", bayOccupied ? 1 : 0);\n        if bayOccupied {\n          this.bayParkingBypass = true;\n          this.bayParkingActive = false;\n          this.bayParkingStage = 0;\n          this.bayParkingWasEntered = false;\n          this.PublishLoopDiagnostic(50, this.requestedStopId);\n        };\n      };\n    };\n\n    // Intermediate bay stops are deliberately NOT driven into during r375a.\n    // They remain route points, but this reset build isolates actual parking.\n    if !this.followingPassage && this.HasServiceBay() && !Equals(this.requestedStopId, this.serviceStopId) {\n      let skipLateral: Float;\n      let skipLongitudinal: Float = this.GetBayEntryProgress(skipLateral);\n      if skipLongitudinal <= 20.00 && skipLongitudinal >= -4.00 && skipLateral <= 12.00 {\n        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());\n        if !this.AdvanceToNextStop() {\n          this.PublishLoopDiagnostic(34, 0);\n          this.ScheduleDispatch(1.00);\n          return;\n        };\n        this.driveCommandSent = this.controller.DriveToTrafficAfterRollingPassage(this.GetTrafficTarget(), 0.00, rollingSpeed);\n        this.PublishLoopDiagnostic(this.driveCommandSent ? 64 : 33, this.requestedStopId);\n        this.ScheduleDispatch(0.05);\n        return;\n      };\n    };\n\n    // ENTRY: capture the real road centreline locally and issue ONE long direct\n    // ray through the bay. No P1 target, no overshoot, no counter-target.\n    if !this.followingPassage && this.HasServiceBay() && !this.bayParkingActive\n      && !this.bayParkingBypass && Equals(this.requestedStopId, this.serviceStopId) {\n      let entryLateral: Float;\n      let entryLongitudinal: Float = this.GetBayEntryProgress(entryLateral);\n      if entryLongitudinal > 0.50 && entryLongitudinal <= 24.00 && entryLateral <= 12.00 {\n        let forward: Vector4 = this.GetBayForward();\n        let right: Vector4 = new Vector4(-forward.Y, forward.X, 0.00, 0.00);\n        let roadDelta: Vector4 = this.controller.GetWorldPosition() - this.GetBayEntryPoint();\n        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 6.00), 2.00);\n        this.bayParkingRoadLateral = Vector4.Dot(roadDelta, right);\n        this.bayParkingEntryTarget = this.GetBayParkingEntryTarget();\n        this.bayParkingRoadTarget = this.GetBayParkingRoadTarget();\n        this.bayParkingActive = true;\n        this.bayParkingStage = 1;\n        this.bayParkingWasEntered = false;\n        this.bayParkingRetryCount = 0;\n        this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingEntryTarget, entrySpeed, 6.00);\n        this.PublishLoopDiagnostic(this.driveCommandSent ? 60 : 33, this.requestedStopId);\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n    };\n\n    if this.bayParkingActive && this.HasServiceBay() {\n      let bayLateral: Float;\n      let bayProgress: Float = this.GetBayProgress(bayLateral);\n      let bayLength: Float = Vector4.Distance(this.GetBayEntryPoint(), this.GetBayExitPoint());\n      let currentSpeed: Float = AbsF(this.controller.GetCurrentSpeed());\n      let widthTolerance: Float = ClampF(this.GetBayWidth() * 0.75, 1.80, 2.60);\n      if bayProgress >= 0.00 { this.bayParkingWasEntered = true; };\n\n      // STOP: once the front half has genuinely entered and converged toward\n      // the centreline, replace the long ray exactly once with the final berth.\n      if Equals(this.bayParkingStage, 1) {\n        if bayProgress >= bayLength * 0.25 && AbsF(bayLateral) <= widthTolerance {\n          this.bayParkingStage = 2;\n          this.bayParkingRetryCount = 0;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetServiceBerth(), MaxF(MinF(currentSpeed, 3.50), 1.50), 3.50);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 61 : 33, this.requestedStopId);\n          this.ScheduleDispatch(0.10);\n          return;\n        };\n        if this.controller.IsRouteCommandFailed() && this.bayParkingRetryCount < 1 {\n          this.bayParkingRetryCount += 1;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingEntryTarget, MaxF(MinF(currentSpeed, 6.00), 2.00), 6.00);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 65 : 33, this.requestedStopId);\n        };\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n\n      if Equals(this.bayParkingStage, 2) {\n        if this.controller.IsStoppedNear(this.GetServiceBerth(), 4.50)\n          || (this.controller.IsRouteCommandSuccessful() && this.controller.IsNear(this.GetServiceBerth(), 6.00)) {\n          this.controller.ArriveAtStop();\n          this.arrived = true;\n          this.bayParkingActive = false;\n          this.bayParkingStage = 0;\n          this.driveCommandSent = false;\n          this.dwellPolls = 0;\n          quests.SetFact(n"nctc_service_bus_at_stop", 1);\n          this.controller.KeepPassengerDoorOpen();\n          this.PublishLoopDiagnostic(62, this.requestedStopId);\n          this.ScheduleDispatch(0.25);\n          return;\n        };\n        if this.controller.IsRouteCommandFailed() && this.bayParkingRetryCount < 1 {\n          this.bayParkingRetryCount += 1;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetServiceBerth(), 1.50, 3.00);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 66 : 33, this.requestedStopId);\n        };\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n\n      // EXIT: one direct ray from the parked berth to the locally captured road\n      // line. Advance route state only after the bus is physically back out.\n      if Equals(this.bayParkingStage, 3) {\n        if (bayProgress >= bayLength + 2.00 && this.controller.IsNear(this.bayParkingRoadTarget, 6.00))\n          || (this.controller.IsRouteCommandSuccessful() && this.controller.IsNear(this.bayParkingRoadTarget, 7.00)) {\n          let rollingSpeed: Float = currentSpeed;\n          this.bayParkingActive = false;\n          this.bayParkingStage = 0;\n          this.bayParkingRetryCount = 0;\n          if !this.AdvanceToNextStop() {\n            this.PublishLoopDiagnostic(34, 0);\n            this.ScheduleDispatch(1.00);\n            return;\n          };\n          this.driveCommandSent = this.controller.DriveToTrafficAfterRollingPassage(this.GetTrafficTarget(), 0.00, rollingSpeed);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 63 : 33, this.requestedStopId);\n          this.ScheduleDispatch(0.05);\n          return;\n        };\n        if this.controller.IsRouteCommandFailed() && this.bayParkingRetryCount < 1 {\n          this.bayParkingRetryCount += 1;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingRoadTarget, MaxF(MinF(currentSpeed, 5.00), 2.00), 5.00);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 67 : 33, this.requestedStopId);\n        };\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n    };\n\n    // Road-stop / occupied-bay fallback remains native traffic.\n    // The native Mahir controller settles the pivot before the target.'''
s, n = parking_pat.subn(parking_new, s, count=1)
assert n == 1, 'old bay state machine not replaced'

# 11) Generic arrival and failure fallback now reference only fresh state.
s = s.replace('this.bayParkingBypass ? 12.00 : 7.00', 'this.bayParkingBypass ? 12.00 : 7.00')
s = s.replace('        this.bayParkingActive = false;\n        this.bayParkingStage = 0;\n        // r374m: preserve stop state through dwell; successor reset follows.\n', '        this.bayParkingActive = false;\n        this.bayParkingStage = 0;\n')
s = s.replace('      if this.bayParkingActive {\n        this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetActiveBerthTarget(), AbsF(this.controller.GetCurrentSpeed()));\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n', '')

# Any remaining DriveToBerthDirect call must use the new explicit max-speed signature.
# Fail fast rather than silently shipping mixed r374/r375 code.
for forbidden in [
    'berthManeuver', 'berthWasEntered', 'berthBypassActive', 'berthMergeSignedLateral',
    'berthGateRoadSignedLateral', 'departureManeuverActive', 'departureCurveStage',
    'departureStallPolls', 'GetBayCounterTarget', 'GetBayTrackTarget',
    'GetBayExitAttackTarget', 'GetBayRoadRejoinTarget', 'GetBerthEntryTarget',
    'GetApproachBrakeTarget', 'approachSlowdownApplied', 'approachBrakeTarget'
]:
    assert forbidden not in s, f'legacy bay symbol remains: {forbidden}'

# Runtime revision for the clean reset series.
s = s.replace('SetFact(n"nctc_dev_build_revision", 37423);', 'SetFact(n"nctc_dev_build_revision", 37501);')

p.write_text(s, encoding='utf-8')

# CET: only update runtime marker and teach the logger the fresh state codes.
cet = Path('source/cet/nctc_survey/init.lua')
c = cet.read_text(encoding='utf-8')
c = c.replace('37423', '37501')
c = c.replace('r374w rolling bay control rays', 'r375a fresh bay parking reset')
# Add labels only if the table still contains the prior highest bay code.
needle = '    [54] = "route loop: r374v bay watchdog recovery"'
if needle in c:
    c = c.replace(needle, needle + ',\n    [60] = "route loop: r375a bay entry ray",\n    [61] = "route loop: r375a final parking target",\n    [62] = "route loop: r375a parked in bay",\n    [63] = "route loop: r375a bay exit/rejoin",\n    [64] = "route loop: r375a intermediate bay skipped",\n    [65] = "route loop: r375a entry retry",\n    [66] = "route loop: r375a parking retry",\n    [67] = "route loop: r375a exit retry"')
cet.write_text(c, encoding='utf-8')

print('r375a patch applied')
