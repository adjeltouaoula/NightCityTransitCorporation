#!/usr/bin/env bash
set -euo pipefail

BASE_SHA="60f46539837b4a4a7204c91da2fddcb01238cbd8"
CLEAN_BRANCH="experiment/r380b-bay-obstacle-guard"
CLEAN="$RUNNER_TEMP/r380b-clean"
rm -rf "$CLEAN"

git fetch origin "$CLEAN_BRANCH"
git worktree prune
git worktree add -B "$CLEAN_BRANCH" "$CLEAN" "origin/$CLEAN_BRANCH"
test "$(git -C "$CLEAN" rev-parse HEAD)" = "$BASE_SHA"

ARRIVAL_BEFORE="$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Spline.archive)"
DEPARTURE_BEFORE="$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Departure.archive)"
DISPLAY_BEFORE="$(sha256sum "$CLEAN/source/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')"

# Make the stage-10 insertion anchor unique: stage 10 also appears in the
# telemetry branch, but only the real state handler is immediately followed by
# IsSplineCommandSuccessful().
python3 - <<'PY'
from pathlib import Path
p = Path("tools/r380b/patch.py")
s = p.read_text()
old = "anchor = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 10) {'''"
new = "anchor = '''    if this.bayParkingActive && Equals(this.bayParkingStage, 10) {\n      if this.controller.IsSplineCommandSuccessful() {'''"
if s.count(old) != 1:
    raise SystemExit(f"builder patch anchor edit failed: {s.count(old)}")
p.write_text(s.replace(old, new, 1))
PY

python3 tools/r380b/patch.py "$CLEAN"

grep -Fq 'nctc_dev_build_revision", 38002' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'PauseBaySplineForObstacle' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'IsImmediateBayPathBlocked' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'n"Vehicle"' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'n"Dynamic"' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'JoinTrafficVanillaAfterSpline' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'command.useKinematic = true;' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"

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
git -C "$CLEAN" commit -m "feat: r380b add vanilla bay obstacle guard"
CLEAN_SHA="$(git -C "$CLEAN" rev-parse HEAD)"
git -C "$CLEAN" push origin "HEAD:refs/heads/$CLEAN_BRANCH"
test "$(git -C "$CLEAN" rev-list --count "$BASE_SHA..$CLEAN_SHA")" -eq 1

ROOT="$RUNNER_TEMP/nctc-r380b"
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

ZIP="$RUNNER_TEMP/NightCityTransitCorporation-0.3.0-devkit-r380b-bay-obstacle-guard-development.zip"
(cd "$ROOT" && zip -qr "$ZIP" .)
unzip -t "$ZIP" >/dev/null
sha256sum "$ZIP" | tee "$RUNNER_TEMP/r380b.sha256"
printf 'CLEAN_SHA=%s\nBASE_SHA=%s\nARRIVAL_BLOB=%s\nDEPARTURE_BLOB=%s\nDISPLAY_SHA=%s\n' \
  "$CLEAN_SHA" "$BASE_SHA" "$ARRIVAL_BEFORE" "$DEPARTURE_BEFORE" "$DISPLAY_BEFORE" > "$RUNNER_TEMP/r380b-metadata.txt"
