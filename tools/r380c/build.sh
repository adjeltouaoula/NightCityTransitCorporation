#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="411eadf5628fcbc4199feaa63fd0deaa122faf51"
SOURCE_SHA="348da92613f75db4258cb19a1fb61b7ebc503877"
CLEAN_BRANCH="experiment/r380c-clean-vanilla-rejoin-safety"
CLEAN="$RUNNER_TEMP/r380c-clean"
rm -rf "$CLEAN"

git fetch origin "$CLEAN_BRANCH"
git worktree prune
git worktree add -B "$CLEAN_BRANCH" "$CLEAN" "origin/$CLEAN_BRANCH"
test "$(git -C "$CLEAN" rev-parse HEAD)" = "$BASE_SHA"

ARRIVAL_BEFORE="$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Spline.archive)"
DEPARTURE_BEFORE="$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Departure.archive)"
DISPLAY_BEFORE="$(sha256sum "$CLEAN/source/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')"

# Copy only the two reviewed r380b source files onto the validated r376f tree.
git show "$SOURCE_SHA:source/redscript/NCTC/NCTCTransitSystem.reds" > "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
git show "$SOURCE_SHA:source/cet/nctc_survey/init.lua" > "$CLEAN/source/cet/nctc_survey/init.lua"

python3 - "$CLEAN" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
transit = root / "source/redscript/NCTC/NCTCTransitSystem.reds"
s = transit.read_text()

old = 'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38002);'
new = 'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 38003);'
if s.count(old) != 1:
    raise SystemExit(f"runtime revision anchor failed: {s.count(old)}")
s = s.replace(old, new, 1)

anchor = '''  // r376b: the departure spline has already completed successfully here,
  // so do not interrupt it again. Hand the measured rolling speed to the
  // normal traffic navigator through the established generation-safe pulse.
  public func DriveToTrafficAfterSpline(target: Vector4, minimumDistance: Float, startSpeed: Float) -> Bool {'''
method = '''  // r380c: once vanilla JoinTraffic has attached the Mahir to a traffic lane,
  // do NOT pulse NoDriver again. End only the temporary JoinTraffic command and
  // submit the normal traffic route while preserving the lane-attached state.
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
    if IsDefined(this.activeJoinTrafficCommand) {
      this.bus.GetAIComponent().StopExecutingCommand(this.activeJoinTrafficCommand, true);
      this.activeJoinTrafficCommand = null;
    };

    callback = new NCTCDeferredDriveCommand();
    speedLimit = this.ResolveTrafficSpeed(target, speedProfile);
    callback.Configure(this.bus, this, target, minimumDistance, speedLimit, speedProfile, MaxF(startSpeed, 0.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.030, false);
    return true;
  }

'''
if s.count(anchor) != 1:
    raise SystemExit(f"joined-lane method anchor failed: {s.count(anchor)}")
s = s.replace(anchor, method + anchor, 1)

old = 'this.driveCommandSent = this.controller.DriveToTrafficAfterSpline(this.GetTrafficTarget(), 0.00, joinedSpeed);'
new = 'this.driveCommandSent = this.controller.DriveToTrafficFromJoinedLane(this.GetTrafficTarget(), 0.00, joinedSpeed);'
if s.count(old) != 2:
    raise SystemExit(f"joined-lane call count changed: {s.count(old)}")
# Replace only the successful IsInTrafficLane branch. The timeout/failure branch
# deliberately keeps the old r376f recovery path with its driver reset.
s = s.replace(old, new, 1)

transit.write_text(s)

cet = root / "source/cet/nctc_survey/init.lua"
c = cet.read_text()
old = '''  if revision == 38002 then
    log("NCTC runtime build=38002 r380b vanilla join + bay Vehicle/Dynamic obstacle guard")'''
new = '''  if revision == 38003 then
    log("NCTC runtime build=38003 r380c clean vanilla lane rejoin + bay obstacle guard")'''
if c.count(old) != 1:
    raise SystemExit(f"CET build anchor failed: {c.count(old)}")
c = c.replace(old, new, 1)
cet.write_text(c)
PY

grep -Fq 'nctc_dev_build_revision", 38003' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'DriveToTrafficFromJoinedLane' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'StopExecutingCommand(this.activeJoinTrafficCommand, true)' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'command.useKinematic = true;' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'IsImmediateBayPathBlocked' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'n"Vehicle"' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'n"Dynamic"' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"

test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Spline.archive)" = "$ARRIVAL_BEFORE"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Departure.archive)" = "$DEPARTURE_BEFORE"
test "$(sha256sum "$CLEAN/source/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')" = "$DISPLAY_BEFORE"

mapfile -t CHANGED < <(git -C "$CLEAN" diff --name-only)
test "${#CHANGED[@]}" -eq 2
printf '%s\n' "${CHANGED[@]}" | grep -Fxq 'source/redscript/NCTC/NCTCTransitSystem.reds'
printf '%s\n' "${CHANGED[@]}" | grep -Fxq 'source/cet/nctc_survey/init.lua'

git -C "$CLEAN" config user.name "github-actions[bot]"
git -C "$CLEAN" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$CLEAN" add source/redscript/NCTC/NCTCTransitSystem.reds source/cet/nctc_survey/init.lua
git -C "$CLEAN" commit -m "feat: r380c clean vanilla rejoin and bay safety"
CLEAN_SHA="$(git -C "$CLEAN" rev-parse HEAD)"
git -C "$CLEAN" push origin "HEAD:refs/heads/$CLEAN_BRANCH"
test "$(git -C "$CLEAN" rev-list --count "$BASE_SHA..$CLEAN_SHA")" -eq 1

ROOT="$RUNNER_TEMP/nctc-r380c"
rm -rf "$ROOT"
mkdir -p "$ROOT/archive/pc/mod" "$ROOT/r6/scripts/NCTC" "$ROOT/r6/tweaks/NCTC"
mkdir -p "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey"
mkdir -p "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_passenger"
cp "$CLEAN"/source/archive/pc/mod/*.archive "$ROOT/archive/pc/mod/"
cp "$CLEAN"/source/archive/pc/mod/*.archive.xl "$ROOT/archive/pc/mod/"
cp "$CLEAN"/source/redscript/NCTC/*.reds "$ROOT/r6/scripts/NCTC/"
cp "$CLEAN"/source/tweaks/NCTC/* "$ROOT/r6/tweaks/NCTC/"
cp "$CLEAN/source/cet/nctc_survey/init.lua" "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/"
cp "$CLEAN/source/cet/nctc_survey/nctc_network.default.json" "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/"
cp "$CLEAN/source/cet/nctc_survey/nctc_survey_settings.json" "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/"
cp "$CLEAN"/source/cet/nctc_passenger/* "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_passenger/"
cp "$CLEAN/README.md" "$CLEAN/THIRD_PARTY_NOTICES.md" "$ROOT/"

ZIP="$RUNNER_TEMP/NightCityTransitCorporation-0.3.0-devkit-r380c-clean-vanilla-rejoin-safety-development.zip"
(cd "$ROOT" && zip -qr "$ZIP" .)
unzip -t "$ZIP" >/dev/null
sha256sum "$ZIP" | tee "$RUNNER_TEMP/r380c.sha256"
printf 'CLEAN_SHA=%s\nBASE_SHA=%s\nARRIVAL_BLOB=%s\nDEPARTURE_BLOB=%s\nDISPLAY_SHA=%s\n' \
  "$CLEAN_SHA" "$BASE_SHA" "$ARRIVAL_BEFORE" "$DEPARTURE_BEFORE" "$DISPLAY_BEFORE" > "$RUNNER_TEMP/r380c-metadata.txt"
