from pathlib import Path

transit = Path('source/redscript/NCTC/NCTCTransitSystem.reds')
s = transit.read_text(encoding='utf-8')

s = s.replace('SetFact(n"nctc_dev_build_revision", 37501);', 'SetFact(n"nctc_dev_build_revision", 37502);', 1)

old = '''      let widthTolerance: Float = ClampF(this.GetBayWidth() * 0.75, 1.80, 2.60);\n      if bayProgress >= 0.00 { this.bayParkingWasEntered = true; };\n\n      // STOP: once the front half has genuinely entered and converged toward\n      // the centreline, replace the long ray exactly once with the final berth.\n      if Equals(this.bayParkingStage, 1) {\n        if bayProgress >= bayLength * 0.25 && AbsF(bayLateral) <= widthTolerance {\n          this.bayParkingStage = 2;\n          this.bayParkingRetryCount = 0;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetServiceBerth(), MaxF(MinF(currentSpeed, 3.50), 1.50), 3.50);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 61 : 33, this.requestedStopId);\n          this.ScheduleDispatch(0.10);\n          return;\n        };\n        if this.controller.IsRouteCommandFailed() && this.bayParkingRetryCount < 1 {\n          this.bayParkingRetryCount += 1;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingEntryTarget, MaxF(MinF(currentSpeed, 6.00), 2.00), 6.00);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 65 : 33, this.requestedStopId);\n        };\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n\n      if Equals(this.bayParkingStage, 2) {\n        if this.controller.IsStoppedNear(this.GetServiceBerth(), 4.50)\n          || (this.controller.IsRouteCommandSuccessful() && this.controller.IsNear(this.GetServiceBerth(), 6.00)) {\n          this.controller.ArriveAtStop();\n          this.arrived = true;\n          this.bayParkingActive = false;\n          this.bayParkingStage = 0;\n          this.driveCommandSent = false;\n          this.dwellPolls = 0;\n          quests.SetFact(n"nctc_service_bus_at_stop", 1);\n          this.controller.KeepPassengerDoorOpen();\n          this.PublishLoopDiagnostic(62, this.requestedStopId);\n          this.ScheduleDispatch(0.25);\n          return;\n        };\n        if this.controller.IsRouteCommandFailed() && this.bayParkingRetryCount < 1 {\n          this.bayParkingRetryCount += 1;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetServiceBerth(), 1.50, 3.00);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 66 : 33, this.requestedStopId);\n        };\n        this.ScheduleDispatch(0.10);\n        return;\n      };'''

new = '''      let widthTolerance: Float = ClampF(this.GetBayWidth() * 0.75, 1.80, 2.60);\n      if bayProgress >= 0.00 { this.bayParkingWasEntered = true; };\n\n      // r375b: the r375a log proved that waiting for lateral convergence makes\n      // the switch happen at 60% on H2, after P2 on Cannery, and never at all\n      // on Delamain. P1/P2 already give us a trustworthy longitudinal frame,\n      // so begin braking at a fixed early progress and let the final target\n      // pull the remaining lateral error out while there is still road length.\n      if Equals(this.bayParkingStage, 1) {\n        if bayProgress >= bayLength * 0.22 {\n          this.bayParkingStage = 2;\n          this.bayParkingRetryCount = 0;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetServiceBerth(), MaxF(MinF(currentSpeed, 3.00), 1.25), 3.00);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 61 : 33, this.requestedStopId);\n          this.ScheduleDispatch(0.10);\n          return;\n        };\n        if this.controller.IsRouteCommandFailed() && this.bayParkingRetryCount < 1 {\n          this.bayParkingRetryCount += 1;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.bayParkingEntryTarget, MaxF(MinF(currentSpeed, 6.00), 2.00), 6.00);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 65 : 33, this.requestedStopId);\n        };\n        this.ScheduleDispatch(0.10);\n        return;\n      };\n\n      if Equals(this.bayParkingStage, 2) {\n        // Parking is a PHYSICAL bay state, not an exact-point state. r375a H2\n        // stopped straight and safely inside P1/P2 but 9.2 m beyond the 65%\n        // reference, so a 4.5/6 m radius could never finish the maneuver.\n        let parkedInsideBay: Bool = currentSpeed <= 0.50\n          && bayProgress >= bayLength * 0.35\n          && bayProgress <= bayLength + 1.50\n          && AbsF(bayLateral) <= ClampF(this.GetBayWidth() * 1.20, 2.50, 4.00);\n        if parkedInsideBay {\n          this.controller.ArriveAtStop();\n          this.arrived = true;\n          this.bayParkingActive = false;\n          this.bayParkingStage = 0;\n          this.driveCommandSent = false;\n          this.dwellPolls = 0;\n          quests.SetFact(n"nctc_service_bus_at_stop", 1);\n          this.controller.KeepPassengerDoorOpen();\n          this.PublishLoopDiagnostic(62, this.requestedStopId);\n          this.ScheduleDispatch(0.25);\n          return;\n        };\n        // If the native command has already settled outside the physical bay,\n        // allow one slow correction. Never spin indefinitely around the point.\n        if (this.controller.IsRouteCommandFailed()\n          || (this.controller.IsRouteCommandSuccessful() && currentSpeed <= 0.50))\n          && this.bayParkingRetryCount < 1 {\n          this.bayParkingRetryCount += 1;\n          this.driveCommandSent = this.controller.DriveToBerthDirect(this.GetServiceBerth(), 1.00, 2.00);\n          this.PublishLoopDiagnostic(this.driveCommandSent ? 66 : 33, this.requestedStopId);\n        };\n        this.ScheduleDispatch(0.10);\n        return;\n      };'''

if old not in s:
    raise SystemExit('r375a stage block not found')
s = s.replace(old, new, 1)
transit.write_text(s, encoding='utf-8')

lua = Path('source/cet/nctc_survey/init.lua')
l = lua.read_text(encoding='utf-8')
for code, label in {
    60: 'route loop: r375b bay entry ray',
    61: 'route loop: r375b early progress parking target',
    62: 'route loop: r375b physically parked in bay',
    63: 'route loop: r375b bay exit/rejoin',
    64: 'route loop: r375b intermediate bay skipped',
    65: 'route loop: r375b entry retry',
    66: 'route loop: r375b one-shot parking correction',
    67: 'route loop: r375b exit retry',
}.items():
    import re
    l, n = re.subn(rf'    \[{code}\] = "[^"]+"', f'    [{code}] = "{label}"', l, count=1)
    if n != 1:
        raise SystemExit(f'logger code {code} not found')

l = l.replace('if code == 29 or code == 30 or code == 36 or code == 43 or code == 47 or code == 48 or code == 49 or code == 50 or code == 51 or code == 52 or code == 53 or code == 54 then',
'''if code == 29 or code == 30 or code == 36 or code == 43 or code == 47 or code == 48 or code == 49 or code == 50 or code == 51 or code == 52 or code == 53 or code == 54\n    or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 then''', 1)
l = l.replace('if revision == 37501 then\n    log("NCTC runtime build=37501 r375a fresh bay parking reset")',
'''if revision == 37502 then\n    log("NCTC runtime build=37502 r375b early-progress parking + physical bay arrival")\n  elseif revision == 37501 then\n    log("NCTC runtime build=37501 r375a fresh bay parking reset")''', 1)
lua.write_text(l, encoding='utf-8')

print('r375b patch applied')
