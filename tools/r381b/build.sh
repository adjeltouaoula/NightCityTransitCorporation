#!/usr/bin/env bash
set -euo pipefail

BASE_BRANCH="experiment/r381a-h2-direct-vanilla-join"
CLEAN_BRANCH="experiment/r381b-h2-direct-join-vehicle-gap"
CLEAN="$RUNNER_TEMP/r381b-clean"
rm -rf "$CLEAN"

git fetch origin "$BASE_BRANCH" "$CLEAN_BRANCH"
git worktree prune
git worktree add -B "$CLEAN_BRANCH" "$CLEAN" "origin/$BASE_BRANCH"
BASE_SHA="$(git -C "$CLEAN" rev-parse HEAD)"

ARRIVAL_BEFORE="$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Spline.archive)"
DEPARTURE_BEFORE="$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Departure.archive)"
DISPLAY_BEFORE="$(sha256sum "$CLEAN/source/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')"

python3 tools/r381b/patch.py "$CLEAN"

grep -Fq 'nctc_dev_build_revision", 38102' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'IsDepartureMergeVehicleBlocked' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'JoinTrafficDirectFromBerth' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
grep -Fq 'command.useKinematic = true;' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
! grep -Fq 'DriveOnBaySpline("$/nctc/bays/h2/departure_spline", exitSpeed, false);' "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Spline.archive)" = "$ARRIVAL_BEFORE"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Departure.archive)" = "$DEPARTURE_BEFORE"
test "$(sha256sum "$CLEAN/source/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')" = "$DISPLAY_BEFORE"

mapfile -t CHANGED < <(git -C "$CLEAN" diff --name-only)
for f in "${CHANGED[@]}"; do echo "changed: $f"; done
test "${#CHANGED[@]}" -eq 1
printf '%s\n' "${CHANGED[@]}" | grep -Fxq 'source/redscript/NCTC/NCTCTransitSystem.reds'

git -C "$CLEAN" config user.name "github-actions[bot]"
git -C "$CLEAN" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$CLEAN" add source/redscript/NCTC/NCTCTransitSystem.reds
git -C "$CLEAN" commit -m "test: r381b gate direct JoinTraffic on adjacent vehicles"
CLEAN_SHA="$(git -C "$CLEAN" rev-parse HEAD)"
git -C "$CLEAN" push --force origin "HEAD:refs/heads/$CLEAN_BRANCH"

ROOT="$RUNNER_TEMP/nctc-r381b"
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

REALZIP="$RUNNER_TEMP/NightCityTransitCorporation-0.3.0-devkit-r381b-h2-direct-join-vehicle-gap-development.zip"
(cd "$ROOT" && zip -qr "$REALZIP" .)
unzip -t "$REALZIP" >/dev/null
sha256sum "$REALZIP" | tee "$RUNNER_TEMP/r381b.sha256"
printf 'BASE_SHA=%s\nCLEAN_SHA=%s\nARRIVAL_BLOB=%s\nDEPARTURE_BLOB=%s\nDISPLAY_SHA=%s\n' "$BASE_SHA" "$CLEAN_SHA" "$ARRIVAL_BEFORE" "$DEPARTURE_BEFORE" "$DISPLAY_BEFORE" > "$RUNNER_TEMP/r381b-metadata.txt"
