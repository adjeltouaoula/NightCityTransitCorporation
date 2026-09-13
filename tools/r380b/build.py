from pathlib import Path
import shutil, subprocess, tempfile

REPO = Path.cwd()
BASE_SHA = "e3a4b34c848e1c99a40026c23192f9c14070f37c"
CLEAN_BRANCH = "experiment/r380b-clean-vanilla-rejoin-bay-safety"

def run(*args, cwd=None, capture=False):
    kw = {"cwd": cwd or REPO, "check": True, "text": True}
    if capture: kw["stdout"] = subprocess.PIPE
    p = subprocess.run(args, **kw)
    return p.stdout.strip() if capture else None

def once(text, old, new, label):
    n = text.count(old)
    if n != 1: raise RuntimeError(f"{label}: expected 1 match, got {n}")
    return text.replace(old, new, 1)

run("git", "fetch", "origin", CLEAN_BRANCH)
clean = Path(tempfile.gettempdir()) / "r380b-clean"
if clean.exists(): shutil.rmtree(clean)
run("git", "worktree", "prune")
run("git", "worktree", "add", "-B", CLEAN_BRANCH, str(clean), f"origin/{CLEAN_BRANCH}")
assert run("git", "rev-parse", "HEAD", cwd=clean, capture=True) == BASE_SHA

arrival_before = run("git", "hash-object", "source/archive/pc/mod/NCTCH2Spline.archive", cwd=clean, capture=True)
departure_before = run("git", "hash-object", "source/archive/pc/mod/NCTCH2Departure.archive", cwd=clean, capture=True)
display_before = run("sha256sum", "source/archive/pc/mod/NCTCDisplayPrototype.archive", cwd=clean, capture=True).split()[0]

p = clean / "source/redscript/NCTC/NCTCTransitSystem.reds"
s = p.read_text()
s = once(s,
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38001);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38002);',
    "revision")

needle = '''  public func DistanceToPlayer() -> Float {
    let player: ref<PlayerPuppet>;
    if !this.IsReady() { return 0.00; };
    player = GetPlayer(this.bus.GetGame());
    return IsDefined(player) ? Vector4.Distance(player.GetWorldPosition(), this.bus.GetWorldPosition()) : 0.00;
  }
'''
safety = '''  public func DistanceToPlayer() -> Float {
    let player: ref<PlayerPuppet>;
    if !this.IsReady() { return 0.00; };
    player = GetPlayer(this.bus.GetGame());
    return IsDefined(player) ? Vector4.Distance(player.GetWorldPosition(), this.bus.GetWorldPosition()) : 0.00;
  }

  // r380b: local vanilla-style safety probe for spline motion. The vehicle's
  // CrowdMember component owns the normal moving-path clearance test. A short
  // Dynamic physics overlap supplements it for loose/physics objects that are
  // not traffic members. This probe only covers the Mahir's immediate path.
  public func IsBayPathClear() -> Bool {
    let spatial: ref<SpatialQueriesSystem>;
    let result: TraceResult;
    let dimensions: Vector4;
    let rotation: EulerAngles;
    let forward: Vector4;
    let center: Vector4;
    let lookAhead: Float;
    let dynamicDepth: Float;
    let crowdClear: Bool = true;
    let dynamicBlocked: Bool = false;
    if !this.IsReady() { return true; };

    lookAhead = ClampF(8.00 + AbsF(this.bus.GetCurrentSpeed()) * 1.10, 8.00, 18.00);
    if IsDefined(this.bus.GetCrowdMemberComponent()) {
      crowdClear = this.bus.GetCrowdMemberComponent().CheckEmptyPath(lookAhead);
    };

    spatial = GameInstance.GetSpatialQueriesSystem(this.bus.GetGame());
    if IsDefined(spatial) {
      forward = Vector4.Normalize2D(this.bus.GetWorldForward());
      if AbsF(forward.X) > 0.01 || AbsF(forward.Y) > 0.01 {
        // Begin beyond the bus pivot/body centre so the Mahir cannot detect
        // itself. The box stays narrow and follows the current spline heading.
        dynamicDepth = MaxF(lookAhead - 5.50, 3.00);
        center = this.bus.GetWorldPosition() + forward * (5.50 + dynamicDepth * 0.50);
        center.Z += 1.25;
        dimensions = new Vector4(1.70, dynamicDepth * 0.50, 1.40, 0.00);
        rotation = Quaternion.ToEulerAngles(Quaternion.BuildFromDirectionVector(forward));
        dynamicBlocked = spatial.Overlap(dimensions, center, rotation, n"Dynamic", result);
      };
    };

    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_bay_lookahead_mm", Cast<Int32>(lookAhead * 1000.00));
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_bay_crowd_clear", crowdClear ? 1 : 0);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_bay_dynamic_blocked", dynamicBlocked ? 1 : 0);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_bay_path_clear", crowdClear && !dynamicBlocked ? 1 : 0);
    return crowdClear && !dynamicBlocked;
  }

  public func PauseBayMovementForObstacle() -> Void {
    if !this.IsReady() { return; };
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleOnSplineCommand", false, true);
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
  }
'''
s = once(s, needle, safety, "safety methods")

s = once(s,
'''    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    this.activeJoinTrafficCommand = null;
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00));''',
'''    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    // End the rejoin command without resetting the driver lifecycle. The lane
    // attachment is already established; only the command object is replaced.
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleJoinTrafficCommand", false, true);
    this.activeJoinTrafficCommand = null;
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_command_forced_start_speed_mm", Cast<Int32>(MaxF(startSpeed, 0.00) * 1000.00));''',
"joined-lane command replacement")

old_depart = '''        if Equals(this.requestedStopId, 70) {
          this.bayParkingStage = 12;
          this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);
          this.ScheduleDispatch(0.10);
          return;
        };'''
new_depart = '''        if Equals(this.requestedStopId, 70) {
          if !this.controller.IsBayPathClear() {
            this.bayParkingStage = 16;
            this.driveCommandSent = true;
            this.PublishLoopDiagnostic(83, this.requestedStopId);
          } else {
            this.bayParkingStage = 12;
            this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);
            this.PublishLoopDiagnostic(this.driveCommandSent ? 72 : 33, this.requestedStopId);
          };
          this.ScheduleDispatch(0.10);
          return;
        };'''
s = once(s, old_depart, new_depart, "departure gate")

old_arrival = '''      if entryLongitudinal > 0.50 && entryLongitudinal <= 24.00 && entryLateral <= 12.00 {
        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 6.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingStage = 10;
        this.bayParkingWasEntered = true;
        this.bayParkingRetryCount = 0;
        this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/arrival_spline", entrySpeed, true);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 68 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };'''
new_arrival = '''      if entryLongitudinal > 0.50 && entryLongitudinal <= 24.00 && entryLateral <= 12.00 {
        let entrySpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 6.00), 2.00);
        this.bayParkingActive = true;
        this.bayParkingWasEntered = true;
        this.bayParkingRetryCount = 0;
        if !this.controller.IsBayPathClear() {
          this.controller.PauseBayMovementForObstacle();
          this.bayParkingStage = 15;
          this.driveCommandSent = true;
          this.PublishLoopDiagnostic(80, this.requestedStopId);
        } else {
          this.bayParkingStage = 10;
          this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/arrival_spline", entrySpeed, true);
          this.PublishLoopDiagnostic(this.driveCommandSent ? 68 : 33, this.requestedStopId);
        };
        this.ScheduleDispatch(0.10);
        return;
      };'''
s = once(s, old_arrival, new_arrival, "arrival gate")

s = once(s,
'''    if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
      if this.controller.IsSplineCommandSuccessful() {''',
'''    if this.bayParkingActive && Equals(this.bayParkingStage, 10) {
      if !this.controller.IsBayPathClear() {
        this.controller.PauseBayMovementForObstacle();
        this.bayParkingRetryCount = 0;
        this.bayParkingStage = 15;
        this.driveCommandSent = true;
        this.PublishLoopDiagnostic(81, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      if this.controller.IsSplineCommandSuccessful() {''',
"arrival active safety")

s = once(s,
'''    if this.bayParkingActive && Equals(this.bayParkingStage, 11) {
      this.ScheduleDispatch(0.25);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {''',
'''    if this.bayParkingActive && Equals(this.bayParkingStage, 11) {
      this.ScheduleDispatch(0.25);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 15) {
      if this.controller.IsBayPathClear() {
        this.bayParkingRetryCount += 1;
      } else {
        this.bayParkingRetryCount = 0;
      };
      if this.bayParkingRetryCount >= 2 {
        let restartSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 3.00), 1.25);
        this.bayParkingRetryCount = 0;
        this.bayParkingStage = 10;
        this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/arrival_spline", restartSpeed, true);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 82 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {''',
"arrival safety hold")

s = once(s,
'''    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
      if this.controller.IsSplineCommandSuccessful() {''',
'''    if this.bayParkingActive && Equals(this.bayParkingStage, 12) {
      if !this.controller.IsBayPathClear() {
        this.controller.PauseBayMovementForObstacle();
        this.bayParkingRetryCount = 0;
        this.bayParkingStage = 16;
        this.driveCommandSent = true;
        this.PublishLoopDiagnostic(84, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      if this.controller.IsSplineCommandSuccessful() {''',
"departure active safety")

stage14 = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 14) {
      let inTrafficLane: Bool = this.controller.IsInTrafficLane();'''
stage16 = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 16) {
      if this.controller.IsBayPathClear() {
        this.bayParkingRetryCount += 1;
      } else {
        this.bayParkingRetryCount = 0;
      };
      if this.bayParkingRetryCount >= 2 {
        let restartSpeed: Float = MaxF(MinF(AbsF(this.controller.GetCurrentSpeed()), 3.00), 1.25);
        this.bayParkingRetryCount = 0;
        this.bayParkingStage = 12;
        this.driveCommandSent = this.controller.DriveOnBaySpline("$/nctc/bays/h2/departure_spline", restartSpeed, false);
        this.PublishLoopDiagnostic(this.driveCommandSent ? 85 : 33, this.requestedStopId);
        this.ScheduleDispatch(0.10);
        return;
      };
      this.ScheduleDispatch(0.10);
      return;
    };

'''
s = once(s, stage14, stage16 + stage14, "departure safety hold")

s = once(s,
'      if this.controller.IsJoinTrafficCommandSuccessful() || this.bayParkingRetryCount >= 2 {',
'      if inTrafficLane && (this.controller.IsJoinTrafficCommandSuccessful() || this.bayParkingRetryCount >= 2) {',
"lane attachment guard")
p.write_text(s)

cet = clean / "source/cet/nctc_survey/init.lua"
c = cet.read_text()
c = once(c,
'    [78] = "route loop: r380a vanilla JoinTraffic retry",\n    [79] = "route loop: r380a already lane-attached -> route command"',
'    [78] = "route loop: r380a vanilla JoinTraffic retry",\n    [79] = "route loop: r380a already lane-attached -> route command",\n    [80] = "route loop: r380b arrival waits for local path",\n    [81] = "route loop: r380b arrival obstacle -> spline paused",\n    [82] = "route loop: r380b arrival clear -> spline resumed",\n    [83] = "route loop: r380b departure waits for local path",\n    [84] = "route loop: r380b departure obstacle -> spline paused",\n    [85] = "route loop: r380b departure clear -> spline resumed"',
"CET labels")
needle = '  if code == 76 or code == 77 or code == 78 or code == 79 then'
extra = '''  if code >= 80 and code <= 85 then
    command_extra = command_extra
      .. " bayPathClear=" .. tostring(fact(quests, "nctc_dev_bay_path_clear"))
      .. " crowdClear=" .. tostring(fact(quests, "nctc_dev_bay_crowd_clear"))
      .. " dynamicBlocked=" .. tostring(fact(quests, "nctc_dev_bay_dynamic_blocked"))
      .. " lookAhead=" .. string.format("%.1fm", fact(quests, "nctc_dev_bay_lookahead_mm") / 1000.0)
  end
'''
c = once(c, needle, extra + needle, "CET bay safety telemetry")
c = once(c,
'or code == 76 or code == 77 or code == 78 or code == 79 then',
'or code == 76 or code == 77 or code == 78 or code == 79 or code == 80 or code == 81 or code == 82 or code == 83 or code == 84 or code == 85 then',
"CET code list")
c = once(c,
'  if revision == 38001 then\n    log("NCTC runtime build=38001 r380a clean exact-vanilla traffic rejoin")',
'  if revision == 38002 then\n    log("NCTC runtime build=38002 r380b vanilla rejoin + local bay safety")\n  elseif revision == 38001 then\n    log("NCTC runtime build=38001 r380a clean exact-vanilla traffic rejoin")',
"CET revision")
cet.write_text(c)

assert 'CheckEmptyPath(lookAhead)' in s
assert 'n"Dynamic"' in s
assert 'command.useKinematic = true;' in s
assert 'nctc_dev_build_revision", 38002' in s
assert run("git", "hash-object", "source/archive/pc/mod/NCTCH2Spline.archive", cwd=clean, capture=True) == arrival_before
assert run("git", "hash-object", "source/archive/pc/mod/NCTCH2Departure.archive", cwd=clean, capture=True) == departure_before
assert run("sha256sum", "source/archive/pc/mod/NCTCDisplayPrototype.archive", cwd=clean, capture=True).split()[0] == display_before
changed = run("git", "diff", "--name-only", cwd=clean, capture=True).splitlines()
assert sorted(changed) == sorted(["source/redscript/NCTC/NCTCTransitSystem.reds", "source/cet/nctc_survey/init.lua"]), changed

run("git", "config", "user.name", "github-actions[bot]", cwd=clean)
run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com", cwd=clean)
run("git", "add", "source/redscript/NCTC/NCTCTransitSystem.reds", "source/cet/nctc_survey/init.lua", cwd=clean)
run("git", "commit", "-m", "feat: r380b add local vanilla bay safety", cwd=clean)
clean_sha = run("git", "rev-parse", "HEAD", cwd=clean, capture=True)
run("git", "push", "origin", f"HEAD:refs/heads/{CLEAN_BRANCH}", cwd=clean)
assert run("git", "rev-list", "--count", f"{BASE_SHA}..{clean_sha}", cwd=clean, capture=True) == "1"

root = Path(tempfile.gettempdir()) / "nctc-r380b"
if root.exists(): shutil.rmtree(root)
for d in ["archive/pc/mod", "r6/scripts/NCTC", "r6/tweaks/NCTC", "bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey", "bin/x64/plugins/cyber_engine_tweaks/mods/nctc_passenger"]:
    (root / d).mkdir(parents=True, exist_ok=True)
for q in (clean / "source/archive/pc/mod").glob("*.archive*"): shutil.copy2(q, root / "archive/pc/mod")
for q in (clean / "source/redscript/NCTC").glob("*.reds"): shutil.copy2(q, root / "r6/scripts/NCTC")
for q in (clean / "source/tweaks/NCTC").iterdir():
    if q.is_file(): shutil.copy2(q, root / "r6/tweaks/NCTC")
for name in ["init.lua", "nctc_network.default.json", "nctc_survey_settings.json"]:
    shutil.copy2(clean / "source/cet/nctc_survey" / name, root / "bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey")
for q in (clean / "source/cet/nctc_passenger").iterdir():
    if q.is_file(): shutil.copy2(q, root / "bin/x64/plugins/cyber_engine_tweaks/mods/nctc_passenger")
for name in ["README.md", "THIRD_PARTY_NOTICES.md"]: shutil.copy2(clean / name, root / name)
zip_base = Path(tempfile.gettempdir()) / "NightCityTransitCorporation-0.3.0-devkit-r380b-clean-vanilla-rejoin-bay-safety-development"
zip_path = Path(shutil.make_archive(str(zip_base), "zip", root))
run("unzip", "-t", str(zip_path))
sha = run("sha256sum", str(zip_path), capture=True)
(Path(tempfile.gettempdir()) / "SHA256-r380b.txt").write_text(sha + "\n")
(Path(tempfile.gettempdir()) / "METADATA-r380b.txt").write_text(f"CLEAN_SHA={clean_sha}\nBASE_SHA={BASE_SHA}\nARRIVAL_BLOB={arrival_before}\nDEPARTURE_BLOB={departure_before}\nDISPLAY_SHA={display_before}\n")
print(sha)
