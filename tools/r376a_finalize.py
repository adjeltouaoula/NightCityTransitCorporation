from pathlib import Path

ROOT = Path('.')
TRANSIT = ROOT / 'source/redscript/NCTC/NCTCTransitSystem.reds'
CET = ROOT / 'source/cet/nctc_survey/init.lua'

text = TRANSIT.read_text(encoding='utf-8')

# Use Codeware's public String -> NodeRef helper. This is explicit and easier
# to audit than relying on the lower-level native binding directly.
old = '    command.splineRef = CreateNodeRef(this.splinePath);'
new = '    command.splineRef = ToNodeRef(this.splinePath);'
if old not in text:
    raise SystemExit('r376a spline NodeRef assignment anchor missing')
text = text.replace(old, new, 1)

# The preparatory POC deliberately froze H2 after arrival. r376a-final restores
# the ordinary dwell/departure flow so departure can arm the exit spline.
old = '''      if Equals(this.requestedStopId, 70) && this.HasServiceBay() && this.bayParkingWasEntered {\n        this.ScheduleDispatch(0.25);\n        return;\n      };\n'''
if old not in text:
    raise SystemExit('H2 temporary dwell freeze anchor missing')
text = text.replace(old, '', 1)

# H2 departure is a second native spline. Other bays remain outside this POC.
old = '''      if leaveBayDirect {\n        let exitSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 5.00), 2.00);\n        this.bayParkingActive = true;\n        this.bayParkingStage = 3;\n        this.bayParkingRetryCount = 0;\n        this.bayParkingRoadTarget = this.GetBayParkingRoadTarget();\n        this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingRoadTarget, exitSpeed, 5.00);\n        this.PublishLoopDiagnostic(this.driveCommandSent ? 63 : 33, this.requestedStopId);\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n'''
new = '''      if leaveBayDirect && Equals(this.requestedStopId, 70) {\n        let exitSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 3.00), 1.50);\n        this.bayParkingActive = true;\n        this.bayParkingStage = 12;\n        this.bayParkingRetryCount = 0;\n        this.driveCommandSent = this.controller.DriveOnBaySpline("$/03_night_city/#nctc/#h2_bay_exit", exitSpeed, true);\n        this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n'''
if old not in text:
    raise SystemExit('legacy leaveBayDirect block anchor missing')
text = text.replace(old, new, 1)

# Arrival must reference the two-spline world archive we already compiled.
old = '        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 6.00), 2.00);'
new = '        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 4.00), 1.50);'
if old not in text:
    raise SystemExit('r376a entry speed anchor missing')
text = text.replace(old, new, 1)

old = '        this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/arrival_spline", entrySpeed, true);'
new = '        this.driveCommandSent = this.controller.DriveOnBaySpline("$/03_night_city/#nctc/#h2_bay_entry", entrySpeed, true);'
if old not in text:
    raise SystemExit('r376a arrival NodeRef anchor missing')
text = text.replace(old, new, 1)

# Add the explicit exit-spline state after the arrival failure hold. One native
# command owns the whole exit curve; no DriveToPoint correction is allowed.
anchor = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 11) {\n      this.ScheduleDispatch(0.25);\n      return;\n    };\n\n'''
addition = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 11) {\n      this.ScheduleDispatch(0.25);\n      return;\n    };\n\n    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {\n      if this.controller.IsSplineCommandSuccessful() {\n        let exitRollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());\n        this.bayParkingActive = false;\n        this.bayParkingStage = 0;\n        this.bayParkingRetryCount = 0;\n        this.bayParkingWasEntered = false;\n        if !this.AdvanceToNextStop() {\n          this.PublishLoopDiagnostic(34, 0);\n          this.ScheduleDispatch(1.00);\n          return;\n        };\n        this.driveCommandSent = this.controller.DriveToTrafficAfterRollingPassage(this.GetTrafficTarget(), 0.00, exitRollingSpeed);\n        this.PublishLoopDiagnostic(this.driveCommandSent ? 73 : 33, this.requestedStopId);\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n      if this.controller.IsSplineCommandFailed() {\n        this.bayParkingStage = 13;\n        this.PublishLoopDiagnostic(74, this.requestedStopId);\n        this.ScheduleDispatch(0.25);\n        return;\n      };\n      this.ScheduleDispatch(0.10);\n      return;\n    };\n\n    if this.bayParkingActive && Equals(this.bayParkingStage, 13) {\n      this.ScheduleDispatch(0.25);\n      return;\n    };\n\n'''
if anchor not in text:
    raise SystemExit('r376a stage11 anchor missing')
text = text.replace(anchor, addition, 1)

# Spline telemetry should cover both arrival (10) and exit (12).
old = '      if this.bayParkingActive && Equals(this.bayParkingStage, 10) {'
new = '      if this.bayParkingActive && (Equals(this.bayParkingStage, 10) || Equals(this.bayParkingStage, 12)) {'
if old not in text:
    raise SystemExit('r376a telemetry stage anchor missing')
text = text.replace(old, new, 1)

TRANSIT.write_text(text, encoding='utf-8', newline='\n')

lua = CET.read_text(encoding='utf-8')
old = '''    [70] = "route loop: r376a H2 native spline FAILED",\n    [71] = "route loop: r376a H2 native spline active telemetry"\n'''
new = '''    [70] = "route loop: r376a H2 native arrival spline FAILED",\n    [71] = "route loop: r376a H2 native spline active telemetry",\n    [72] = "route loop: r376a H2 native EXIT spline armed",\n    [73] = "route loop: r376a H2 exit spline complete -> traffic",\n    [74] = "route loop: r376a H2 native exit spline FAILED"\n'''
if old not in lua:
    raise SystemExit('r376a CET diagnostic map anchor missing')
lua = lua.replace(old, new, 1)

old = 'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 then'
new = 'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 then'
if old not in lua:
    raise SystemExit('r376a CET bay detail code list anchor missing')
lua = lua.replace(old, new, 1)

CET.write_text(lua, encoding='utf-8', newline='\n')
print('r376a final H2 two-spline controller patched')
