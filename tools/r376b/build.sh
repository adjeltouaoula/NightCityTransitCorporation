#!/usr/bin/env bash
set -euo pipefail

BASE="857c92b7068a4b7bf026bfbb9b9712884f154090"
CLEAN_BRANCH="experiment/r377a-h2-lane-locked-handoff"
ARRIVAL_BLOB="ff0be26fb781cf5f2aaf9dd75ce5b668f777a0f6"
ARRIVAL_XL_BLOB="6e934a5637bfe3300832eea2fef179386576c5e1"
DISPLAY_SHA="09a8fb10c2e027b2250c1ec647f8c3d466129bea907f5421771795093ae37d0a"
TRANSIT_R376A="479c8652822adee5550babb6c61f536e064b75af"
CET_R376A="08f6f0df2a4be8a0ba0133eec43aeda557e6e68b"

# The tested arrival is immutable in this build.
test "$(git hash-object source/redscript/NCTC/NCTCTransitSystem.reds)" = "$TRANSIT_R376A"
test "$(git hash-object source/cet/nctc_survey/init.lua)" = "$CET_R376A"
test "$(git hash-object source/archive/pc/mod/NCTCH2Spline.archive)" = "$ARRIVAL_BLOB"
test "$(git hash-object source/archive/pc/mod/NCTCH2Spline.archive.xl)" = "$ARRIVAL_XL_BLOB"
test "$(sha256sum source/archive/pc/mod/NCTCDisplayPrototype.archive | awk '{print $1}')" = "$DISPLAY_SHA"

WORK="$RUNNER_TEMP/r377a-world"
RAW="$WORK/NCTCH2Departure"
OUT="$WORK/out"
mkdir -p "$WORK/src" "$RAW/nctc/bays/h2/departure/sectors" "$OUT"
cp tools/r376b/Program.cs "$WORK/src/Program.cs"
pushd "$WORK/src" >/dev/null
dotnet new console --framework net10.0 --force
dotnet add package WolvenKit.RED4 --version 9.0.1
# dotnet new overwrites Program.cs, restore our generator after project creation.
cp "$GITHUB_WORKSPACE/tools/r376b/Program.cs" Program.cs
RAW_ROOT="$RAW" dotnet run -c Release
popd >/dev/null

dotnet tool install WolvenKit.CLI --version 9.0.1 --tool-path "$WORK/tools"
"$WORK/tools/cp77tools" pack "$RAW" -o "$OUT"
test -s "$OUT/NCTCH2Departure.archive"
cp "$OUT/NCTCH2Departure.archive" source/archive/pc/mod/NCTCH2Departure.archive
printf '%s\n' 'streaming:' '  blocks:' '    - nctc\bays\h2\departure\all.streamingblock' > source/archive/pc/mod/NCTCH2Departure.archive.xl

python3 tools/r376b/patch.py

grep -q 'nctc_dev_build_revision.*, 37607' source/redscript/NCTC/NCTCTransitSystem.reds
grep -Fq '$/nctc/bays/h2/arrival_spline' source/redscript/NCTC/NCTCTransitSystem.reds
grep -Fq '$/nctc/bays/h2/departure_spline' source/redscript/NCTC/NCTCTransitSystem.reds
grep -q 'r377a H2 lane-locked handoff' source/cet/nctc_survey/init.lua
test "$(git hash-object source/archive/pc/mod/NCTCH2Spline.archive)" = "$ARRIVAL_BLOB"
test "$(git hash-object source/archive/pc/mod/NCTCH2Spline.archive.xl)" = "$ARRIVAL_XL_BLOB"
test "$(sha256sum source/archive/pc/mod/NCTCDisplayPrototype.archive | awk '{print $1}')" = "$DISPLAY_SHA"

TRANSIT_BLOB="$(git hash-object source/redscript/NCTC/NCTCTransitSystem.reds)"
CET_BLOB="$(git hash-object source/cet/nctc_survey/init.lua)"
DEPARTURE_BLOB="$(git hash-object source/archive/pc/mod/NCTCH2Departure.archive)"
DEPARTURE_XL_BLOB="$(git hash-object source/archive/pc/mod/NCTCH2Departure.archive.xl)"

# Build the clean experimental branch in a separate worktree so helper scripts
# and workflow files can never leak into the user-facing experimental commit.
CLEAN="$RUNNER_TEMP/r377a-clean"
rm -rf "$CLEAN"
git worktree prune
git branch -D "$CLEAN_BRANCH" 2>/dev/null || true
git worktree add -b "$CLEAN_BRANCH" "$CLEAN" "$BASE"
cp source/redscript/NCTC/NCTCTransitSystem.reds "$CLEAN/source/redscript/NCTC/NCTCTransitSystem.reds"
cp source/cet/nctc_survey/init.lua "$CLEAN/source/cet/nctc_survey/init.lua"
cp source/archive/pc/mod/NCTCH2Departure.archive "$CLEAN/source/archive/pc/mod/NCTCH2Departure.archive"
cp source/archive/pc/mod/NCTCH2Departure.archive.xl "$CLEAN/source/archive/pc/mod/NCTCH2Departure.archive.xl"

git -C "$CLEAN" config user.name "github-actions[bot]"
git -C "$CLEAN" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$CLEAN" add source/redscript/NCTC/NCTCTransitSystem.reds source/cet/nctc_survey/init.lua source/archive/pc/mod/NCTCH2Departure.archive source/archive/pc/mod/NCTCH2Departure.archive.xl
git -C "$CLEAN" commit -m "feat: r377a H2 lane-locked traffic handoff"
CLEAN_SHA="$(git -C "$CLEAN" rev-parse HEAD)"
git -C "$CLEAN" push origin "HEAD:refs/heads/$CLEAN_BRANCH"

# Exact clean-branch verification.
test "$(git -C "$CLEAN" hash-object source/redscript/NCTC/NCTCTransitSystem.reds)" = "$TRANSIT_BLOB"
test "$(git -C "$CLEAN" hash-object source/cet/nctc_survey/init.lua)" = "$CET_BLOB"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Spline.archive)" = "$ARRIVAL_BLOB"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Spline.archive.xl)" = "$ARRIVAL_XL_BLOB"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Departure.archive)" = "$DEPARTURE_BLOB"
test "$(git -C "$CLEAN" hash-object source/archive/pc/mod/NCTCH2Departure.archive.xl)" = "$DEPARTURE_XL_BLOB"
test "$(sha256sum "$CLEAN/source/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')" = "$DISPLAY_SHA"

ROOT="$RUNNER_TEMP/nctc-r377a"
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

cat > "$ROOT/NCTC_BUILD_INFO.txt" <<EOF
Night City Transit Corporation
Devkit: r377a H2 lane-locked handoff
Runtime build: 37607
Branch: $CLEAN_BRANCH
Commit: $CLEAN_SHA
Scope: H2 only. The user-validated r376a arrival archive is byte-identical. The r376f departure shape is preserved through point 9; r377a extends the native spline through surveyed passage-3 and ~20 m down its outgoing lane, consumes that already-crossed passage, then performs one rolling handoff to native traffic.
Arrival archive blob: $ARRIVAL_BLOB
Departure archive blob: $DEPARTURE_BLOB
EOF

test ! -e "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/nctc_network.json"
test "$(git hash-object "$ROOT/r6/scripts/NCTC/NCTCTransitSystem.reds")" = "$TRANSIT_BLOB"
test "$(git hash-object "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/init.lua")" = "$CET_BLOB"
test "$(git hash-object "$ROOT/archive/pc/mod/NCTCH2Spline.archive")" = "$ARRIVAL_BLOB"
test "$(git hash-object "$ROOT/archive/pc/mod/NCTCH2Departure.archive")" = "$DEPARTURE_BLOB"
test "$(sha256sum "$ROOT/archive/pc/mod/NCTCDisplayPrototype.archive" | awk '{print $1}')" = "$DISPLAY_SHA"

ZIP="$RUNNER_TEMP/NightCityTransitCorporation-0.3.0-devkit-r377a-h2-lane-locked-handoff-development.zip"
rm -f "$ZIP" "$RUNNER_TEMP/r377a.sha256"
pushd "$ROOT" >/dev/null
zip -qr "$ZIP" .
popd >/dev/null
unzip -t "$ZIP"
sha256sum "$ZIP" | tee "$RUNNER_TEMP/r377a.sha256"

cat > "$RUNNER_TEMP/r377a-metadata.txt" <<EOF
CLEAN_SHA=$CLEAN_SHA
TRANSIT_BLOB=$TRANSIT_BLOB
CET_BLOB=$CET_BLOB
ARRIVAL_BLOB=$ARRIVAL_BLOB
DEPARTURE_BLOB=$DEPARTURE_BLOB
DEPARTURE_XL_BLOB=$DEPARTURE_XL_BLOB
DISPLAY_SHA=$DISPLAY_SHA
EOF

cat "$RUNNER_TEMP/r377a-metadata.txt"
