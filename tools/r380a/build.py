from pathlib import Path
import os
import shutil
import subprocess
import tempfile

REPO = Path.cwd()
BASE_SHA = "411eadf5628fcbc4199feaa63fd0deaa122faf51"
CLEAN_BRANCH = "experiment/r380a-clean-vanilla-rejoin"

def run(*args, cwd=None, capture=False):
    kwargs = {"cwd": cwd or REPO, "check": True, "text": True}
    if capture:
        kwargs["stdout"] = subprocess.PIPE
    p = subprocess.run(args, **kwargs)
    return p.stdout.strip() if capture else None

def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected 1 match, got {count}")
    return text.replace(old, new, 1)

run("git", "fetch", "origin", CLEAN_BRANCH)
clean = Path(tempfile.gettempdir()) / "r380a-clean"
if clean.exists():
    shutil.rmtree(clean)
run("git", "worktree", "prune")
run("git", "worktree", "add", "-B", CLEAN_BRANCH, str(clean), f"origin/{CLEAN_BRANCH}")
assert run("git", "rev-parse", "HEAD", cwd=clean, capture=True) == BASE_SHA

arrival_before = run("git", "hash-object", "source/archive/pc/mod/NCTCH2Spline.archive", cwd=clean, capture=True)
departure_before = run("git", "hash-object", "source/archive/pc/mod/NCTCH2Departure.archive", cwd=clean, capture=True)
display_before = run("sha256sum", "source/archive/pc/mod/NCTCDisplayPrototype.archive", cwd=clean, capture=True).split()[0]

transit = clean / "source/redscript/NCTC/NCTCTransitSystem.reds"
s = transit.read_text()
s = replace_once(s,
    "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let driveGeneration: Int32;",
    "  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  private let activeJoinTrafficCommand: ref<AIVehicleJoinTrafficCommand>;\n  private let driveGeneration: Int32;",
    "join field")
s = replace_once(s,
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37606);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38001);',
    "runtime revision")

old_method = '''  // r376b: the departure spline has already completed successfully here,
  // so do not interrupt it again. Hand the measured rolling speed to the
  // normal traffic navigator through the established generation-safe pulse.
  public func DriveToTrafficAfterSpline(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let speedProfile: Int32;
    let speedLimit: Float;
    let generation: Int32;
    if !this.IsReady() { return false; };

    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;

    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00));

    callback = new NCTCDeferredDriveCommand();
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(this.bus, this, target, minimumDistance, speedLimit, speedProfile, MaxF(startSpeed, 0.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }
'''
new_method = '''  // r380a: use the exact vanilla Delamain free-roam rejoin command first.
  // Delamain uses needDriver=false + useKinematic=true. Route navigation only
  // starts after the Mahir is registered on a traffic lane.
  public func JoinTrafficVanillaAfterSpline() -> Bool {
    let command: ref<AIVehicleJoinTrafficCommand>;
    if !this.IsReady() { return false; };
    this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    this.activeJoinTrafficCommand = null;
    command = new AIVehicleJoinTrafficCommand();
    command.needDriver = false;
    command.useKinematic = true;
    this.bus.GetAIComponent().SendCommand(command);
    this.activeJoinTrafficCommand = command;
    return true;
  }

  public func IsInTrafficLane() -> Bool {
    return this.IsReady() && this.bus.IsInTrafficLane();
  }

  public func IsJoinTrafficCommandSuccessful() -> Bool {
    return IsDefined(this.activeJoinTrafficCommand) && Equals(this.activeJoinTrafficCommand.state, AICommandState.Success);
  }

  public func IsJoinTrafficCommandFailed() -> Bool {
    if !IsDefined(this.activeJoinTrafficCommand) { return false; };
    return Equals(this.activeJoinTrafficCommand.state, AICommandState.Failure)
      || Equals(this.activeJoinTrafficCommand.state, AICommandState.Cancelled)
      || Equals(this.activeJoinTrafficCommand.state, AICommandState.Interrupted);
  }

  public func GetJoinTrafficCommandStatusCode() -> Int32 {
    if !IsDefined(this.activeJoinTrafficCommand) { return 0; };
    if this.IsJoinTrafficCommandSuccessful() { return 2; };
    if this.IsJoinTrafficCommandFailed() { return 3; };
    return 1;
  }

  // The vehicle is already lane-attached here. Do not pulse NoDriver/DriverReady:
  // that lifecycle reset is useful for a fresh route command, but would throw
  // away the traffic state we just asked vanilla JoinTraffic to establish.
  public func DriveToTrafficFromJoinedLane(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredDriveCommand>;
    let speedProfile: Int32;
    let speedLimit: Float;
    let generation: Int32;
    if !this.IsReady() { return false; };
    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    this.activeJoinTrafficCommand = null;
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00));
    callback = new NCTCDeferredDriveCommand();
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(this.bus, this, target, minimumDistance, speedLimit, speedProfile, MaxF(startSpeed, 0.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.030, false);
    return true;
  }
'''
s = replace_once(s, old_method, new_method, "post-spline handoff")

old_success = '''      if this.controller.IsSplineCommandSuccessful() {
        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
        if !this.AdvanceToNextStop() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        this.legPolls = 0;
        this.bayParkingActive = false;
        this.bayParkingStage = 0;
        this.driveCommandSent = this.controller.DriveToTrafficAfterSpline(this.GetTrafficTarget(), 0.00, rollingSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 74 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };'''
new_success = '''      if this.controller.IsSplineCommandSuccessful() {
        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
        if !this.AdvanceToNextStop() {
          this.PublishLoopDiagnostic(34, 0);
          this.ScheduleDispatch(1.00);
          return;
        };
        this.legPolls = 0;
        this.bayParkingRetryCount = 0;
        if this.controller.IsInTrafficLane() {
          this.bayParkingActive = false;
          this.bayParkingStage = 0;
          this.driveCommandSent = this.controller.DriveToTrafficFromJoinedLane(this.GetTrafficTarget(), 0.00, rollingSpeed);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 79 : 33, this.requestedStopId);
        } else {
          this.bayParkingStage = 14;
          this.driveCommandSent = this.controller.JoinTrafficVanillaAfterSpline();
          quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
          quests.SetFact(n"nctc_dev_bus_in_traffic_lane", 0);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 76 : 33, this.requestedStopId);
        };
        this.ScheduleDispatch(0.10);
        return;
      };'''
s = replace_once(s, old_success, new_success, "departure success")

stage13 = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 13) {
      this.ScheduleDispatch(0.25);
      return;
    };
'''
stage14 = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 14) {
      let inTrafficLane: Bool = this.controller.IsInTrafficLane();
      this.legPolls += 1;
      quests.SetFact(n"nctc_dev_join_traffic_state", this.controller.GetJoinTrafficCommandStatusCode());
      quests.SetFact(n"nctc_dev_bus_in_traffic_lane", inTrafficLane ? 1 : 0);
      if inTrafficLane {
        this.bayParkingRetryCount += 1;
      } else {
        this.bayParkingRetryCount = 0;
      };
      if this.controller.IsJoinTrafficCommandSuccessful() || this.bayParkingRetryCount >= 2 {
        let rollingSpeed: Float = AbsF(this.controller.GetCurrentSpeed());
        this.bayParkingActive = false;
        this.bayParkingStage = 0;
        this.legPolls = 0;
        this.driveCommandSent = this.controller.DriveToTrafficFromJoinedLane(this.GetTrafficTarget(), 0.00, rollingSpeed);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 77 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.05);
        return;
      };
      if this.controller.IsJoinTrafficCommandFailed() || this.legPolls >= 50 {
        this.legPolls = 0;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = this.controller.JoinTrafficVanillaAfterSpline();
        this.PublishLoopDiagnostic(this.driveCommandSent ? 78 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

'''
s = replace_once(s, stage13, stage14 + stage13, "join stage")
s = s.replace(
    '// These must remain false for the service bus. Enabling either one lets\n    // the traffic controller snap the long Mahir to a neighboring lane when\n    // a route command starts or ends, which can eject standing passengers.',
    '// Keep neighbor snapping disabled for the service bus: it can visibly\n    // teleport the long Mahir sideways, which is not acceptable RP.', 1)
transit.write_text(s)

cet = clean / "source/cet/nctc_survey/init.lua"
c = cet.read_text()
c = replace_once(c,
    '    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",\n    [75] = "route loop: r376b H2 native departure spline FAILED"',
    '    [74] = "route loop: r376b H2 spline exit -> native traffic handoff",\n    [75] = "route loop: r376b H2 native departure spline FAILED",\n    [76] = "route loop: r380a exact vanilla JoinTraffic armed",\n    [77] = "route loop: r380a traffic lane acquired -> route command",\n    [78] = "route loop: r380a vanilla JoinTraffic retry",\n    [79] = "route loop: r380a already lane-attached -> route command"',
    "CET labels")
needle = '  if code == 29 or code == 31 or code == 32 or code == 41 or code == 46 then'
extra = '''  if code == 76 or code == 77 or code == 78 or code == 79 then
    local join_states = { [0] = "missing", [1] = "active", [2] = "success", [3] = "failed/cancelled" }
    command_extra = command_extra
      .. " joinState=" .. (join_states[fact(quests, "nctc_dev_join_traffic_state")] or "unknown")
      .. " inTrafficLane=" .. tostring(fact(quests, "nctc_dev_bus_in_traffic_lane"))
  end
'''
c = replace_once(c, needle, extra + needle, "CET join telemetry")
c = replace_once(c,
    'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 then',
    'or code == 60 or code == 61 or code == 62 or code == 63 or code == 64 or code == 65 or code == 66 or code == 67 or code == 68 or code == 69 or code == 70 or code == 71 or code == 72 or code == 73 or code == 74 or code == 75 or code == 76 or code == 77 or code == 78 or code == 79 then',
    "CET code list")
c = replace_once(c,
    '  if revision == 37606 then\n    log("NCTC runtime build=37606 r376f H2 final nose clearance")',
    '  if revision == 38001 then\n    log("NCTC runtime build=38001 r380a clean exact-vanilla traffic rejoin")\n  elseif revision == 37606 then\n    log("NCTC runtime build=37606 r376f H2 final nose clearance")',
    "CET revision")
cet.write_text(c)

assert "command.useKinematic = true;" in s
assert "JoinTrafficVanillaAfterSpline" in s
assert "DriveToTrafficFromJoinedLane" in s
assert 'nctc_dev_build_revision", 38001' in s
assert "DriveToTrafficAfterSpline(this.GetTrafficTarget()" not in s
assert run("git", "hash-object", "source/archive/pc/mod/NCTCH2Spline.archive", cwd=clean, capture=True) == arrival_before
assert run("git", "hash-object", "source/archive/pc/mod/NCTCH2Departure.archive", cwd=clean, capture=True) == departure_before
assert run("sha256sum", "source/archive/pc/mod/NCTCDisplayPrototype.archive", cwd=clean, capture=True).split()[0] == display_before
changed = run("git", "diff", "--name-only", cwd=clean, capture=True).splitlines()
assert sorted(changed) == sorted(["source/redscript/NCTC/NCTCTransitSystem.reds", "source/cet/nctc_survey/init.lua"]), changed

run("git", "config", "user.name", "github-actions[bot]", cwd=clean)
run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com", cwd=clean)
run("git", "add", "source/redscript/NCTC/NCTCTransitSystem.reds", "source/cet/nctc_survey/init.lua", cwd=clean)
run("git", "commit", "-m", "feat: r380a clean exact vanilla traffic rejoin", cwd=clean)
clean_sha = run("git", "rev-parse", "HEAD", cwd=clean, capture=True)
run("git", "push", "origin", f"HEAD:refs/heads/{CLEAN_BRANCH}", cwd=clean)
assert run("git", "rev-list", "--count", f"{BASE_SHA}..{clean_sha}", cwd=clean, capture=True) == "1"

root = Path(tempfile.gettempdir()) / "nctc-r380a"
if root.exists(): shutil.rmtree(root)
for d in ["archive/pc/mod", "r6/scripts/NCTC", "r6/tweaks/NCTC", "bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey", "bin/x64/plugins/cyber_engine_tweaks/mods/nctc_passenger"]:
    (root / d).mkdir(parents=True, exist_ok=True)
for p in (clean / "source/archive/pc/mod").glob("*.archive*"): shutil.copy2(p, root / "archive/pc/mod")
for p in (clean / "source/redscript/NCTC").glob("*.reds"): shutil.copy2(p, root / "r6/scripts/NCTC")
for p in (clean / "source/tweaks/NCTC").iterdir():
    if p.is_file(): shutil.copy2(p, root / "r6/tweaks/NCTC")
for name in ["init.lua", "nctc_network.default.json", "nctc_survey_settings.json"]:
    shutil.copy2(clean / "source/cet/nctc_survey" / name, root / "bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey")
for p in (clean / "source/cet/nctc_passenger").iterdir():
    if p.is_file(): shutil.copy2(p, root / "bin/x64/plugins/cyber_engine_tweaks/mods/nctc_passenger")
for name in ["README.md", "THIRD_PARTY_NOTICES.md"]: shutil.copy2(clean / name, root / name)

zip_base = Path(tempfile.gettempdir()) / "NightCityTransitCorporation-0.3.0-devkit-r380a-clean-vanilla-rejoin-development"
zip_path = Path(shutil.make_archive(str(zip_base), "zip", root))
run("unzip", "-t", str(zip_path))
sha = run("sha256sum", str(zip_path), capture=True)
(Path(tempfile.gettempdir()) / "SHA256.txt").write_text(sha + "\n")
(Path(tempfile.gettempdir()) / "METADATA.txt").write_text(
    f"CLEAN_SHA={clean_sha}\nARRIVAL_BLOB={arrival_before}\nDEPARTURE_BLOB={departure_before}\nDISPLAY_SHA={display_before}\n"
)
print(sha)
