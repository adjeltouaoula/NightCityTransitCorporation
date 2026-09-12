#!/usr/bin/env bash
set -euo pipefail

CLEAN_BRANCH="experiment/r378a-h2-native-join-traffic-handoff"
BASE="411eadf5628fcbc4199feaa63fd0deaa122faf51"
ARRIVAL_BLOB="ff0be26fb781cf5f2aaf9dd75ce5b668f777a0f6"
DEPARTURE_BLOB="f22e3fab25ef2fe71fa0c5dc93257b47e4951210"
DISPLAY_SHA="09a8fb10c2e027b2250c1ec647f8c3d466129bea907f5421771795093ae37d0a"

python3 tools/r378a/patch.py

test "$(git hash-object source/archive/pc/mod/NCTCH2Spline.archive)" = "$ARRIVAL_BLOB"
test "$(git hash-object source/archive/pc/mod/NCTCH2Departure.archive)" = "$DEPARTURE_BLOB"
test "$(sha256sum source/archive/pc/mod/NCTCDisplayPrototype.archive | awk '{print $1}')" = "$DISPLAY_SHA"
grep -q 'nctc_dev_build_revision.*, 37801' source/redscript/NCTC/NCTCTransitSystem.reds
grep -q 'new AIVehicleJoinTrafficCommand' source/redscript/NCTC/NCTCTransitSystem.reds
grep -q 'command.useKinematic = false' source/redscript/NCTC/NCTCTransitSystem.reds

CLEAN="$RUNNER_TEMP/r378a-clean"
rm -rf "$CLEAN"
git fetch origin "$CLEAN_BRANCH"
git worktree prune
git worktree add -B "$CLEAN_BRANCH" "$CLEAN" "origin/$CLEAN_BRANCH"
cp source/redscript/NCTC/NCTCTransitSystem.reds "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
cp source/cet/nctc_survey/init.lua "$CLEAN/source/cet/nctc_survey/init.lua"

git -C "$CLEAN" config user.name "github-actions[bot]"
git -C "$CLEAN" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$CLEAN" add source/redscript/NCTC/NCTCTransitSystem.reds source/cet/nctc_survey/init.lua
if ! git -C "$CLEAN" diff --cached --quiet; then
  git -C "$CLEAN" commit -m "feat: r378a native JoinTraffic handoff"
  git -C "$CLEAN" push origin "HEAD:refs/heads/$CLEAN_BRANCH"
fi

CLEAN_SHA="$(git -C "$CLEAN" rev-parse HEAD)"
TRANSIT_BLOB="$(git -C "$CLEAN" hash-object source/redscript/NCTC/NCTCTransitSystem.reds)"
CET_BLOB="$(git -C "$CLEAN" hash-object source/cet/nctc_survey/init.lua)"

test "$(git -C "$CLEAN" merge-base "$BASE" HEAD)" = "$BASE"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Spline.archive)" = "$ARRIVAL_BLOB"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Departure.archive)" = "$DEPARTURE_BLOB"
test "$(sha256sum "$CLEAN/source/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')" = "$DISPLAY_SHA"

ROOT="$RUNNER_TEMP/nctc-r378a"
ZIP="$RUNNER_TEMP/NightCityTransitCorporation-0.3.0-devkit-r378a-h2-native-join-traffic-handoff-development.zip"
rm -rf "$ROOT" "$ZIP"
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

cat > "$ROOT/NCTC_BUILD_INFO.txt" <<EOF
Night City Transit Corporation
Devkit: r378a H2 native JoinTraffic handoff
Runtime build: 37801
Branch: $CLEAN_BRANCH
Commit: $CLEAN_SHA
Base: r376f $BASE
Scope: H2 arrival/departure geometry is byte-identical to validated r376f. Only the post-spline handoff changes: native AIVehicleJoinTrafficCommand(useKinematic=false) first, then the normal NCTC route command after native traffic attachment.
EOF

test ! -e "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/nctc_network.json"
test "$(git hash-object "$ROOT/archive/pc/mod/NCTCH2Spline.archive")" = "$ARRIVAL_BLOB"
test "$(git hash-object "$ROOT/archive/pc/mod/NCTCH2Departure.archive")" = "$DEPARTURE_BLOB"
test "$(sha256sum "$ROOT/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')" = "$DISPLAY_SHA"

pushd "$ROOT" >/dev/null
zip -qr "$ZIP" .
popd >/dev/null
unzip -t "$ZIP"
sha256sum "$ZIP" | tee "$RUNNER_TEMP/r378a.sha256"
cat > "$RUNNER_TEMP/r378a-metadata.txt" <<EOF
CLEAN_SHA=$CLEAN_SHA
TRANSIT_BLOB=$TRANSIT_BLOB
CET_BLOB=$CET_BLOB
ARRIVAL_BLOB=$ARRIVAL_BLOB
DEPARTURE_BLOB=$DEPARTURE_BLOB
DISPLAY_SHA=$DISPLAY_SHA
EOF
cat "$RUNNER_TEMP/r378a-metadata.txt"
