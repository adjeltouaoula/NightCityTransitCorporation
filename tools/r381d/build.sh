#!/usr/bin/env bash
set -euo pipefail
ROOT="$RUNNER_TEMP/nctc-r381d"
rm -rf "$ROOT"
mkdir -p "$ROOT/archive/pc/mod" "$ROOT/r6/scripts/NCTC" "$ROOT/r6/tweaks/NCTC"
mkdir -p "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey"
mkdir -p "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_passenger"
cp source/archive/pc/mod/*.archive "$ROOT/archive/pc/mod/"
cp source/archive/pc/mod/*.archive.xl "$ROOT/archive/pc/mod/"
cp source/redscript/NCTC/*.reds "$ROOT/r6/scripts/NCTC/"
cp source/tweaks/NCTC/* "$ROOT/r6/tweaks/NCTC/"
cp source/cet/nctc_survey/init.lua "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/"
cp source/cet/nctc_survey/nctc_network.default.json "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/"
cp source/cet/nctc_survey/nctc_survey_settings.json "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_survey/"
cp source/cet/nctc_passenger/* "$ROOT/bin/x64/plugins/cyber_engine_tweaks/mods/nctc_passenger/"
cp README.md THIRD_PARTY_NOTICES.md "$ROOT/"
ZIP="$RUNNER_TEMP/NightCityTransitCorporation-0.3.0-devkit-r381d-crowd-empty-path-telemetry-typefix-development.zip"
(cd "$ROOT" && zip -qr "$ZIP" .)
unzip -t "$ZIP" >/dev/null
sha256sum "$ZIP" | tee "$RUNNER_TEMP/r381d.sha256"
