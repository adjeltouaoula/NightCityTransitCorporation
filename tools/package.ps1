param(
    [string]$Version = "0.3.0-devkit",
    [switch]$IncludeSurveyRuntime,
    [switch]$IncludeDisplayPrototype
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
# Builds are kept in the canonical NCTC project distribution folder so every
# development branch publishes to the same installable location.
$distRoot = "C:\MyDocuments\NCBusNetwork\night-city-transit-corporation\dist"
$oldDistRoot = Join-Path $distRoot "old"
$stageRoot = Join-Path $projectRoot "tmp\package\NightCityTransitCorporation"
$archivePath = Join-Path $distRoot "NightCityTransitCorporation-$Version.zip"

if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $stageRoot "r6\scripts\NCTC"), (Join-Path $stageRoot "r6\tweaks\NCTC"), $distRoot, $oldDistRoot | Out-Null
Get-ChildItem -LiteralPath $distRoot -Filter "NightCityTransitCorporation-*.zip" -File | ForEach-Object {
    $oldArchivePath = Join-Path $oldDistRoot $_.Name
    if (Test-Path -LiteralPath $oldArchivePath) { Remove-Item -LiteralPath $oldArchivePath -Force }
    Move-Item -LiteralPath $_.FullName -Destination $oldArchivePath
}
Copy-Item -Path (Join-Path $projectRoot "source\redscript\NCTC\*.reds") -Destination (Join-Path $stageRoot "r6\scripts\NCTC")
Copy-Item -Path (Join-Path $projectRoot "source\tweaks\NCTC\*.yaml") -Destination (Join-Path $stageRoot "r6\tweaks\NCTC")

# Required standalone traffic-driving compatibility resource. Every validated
# autonomous-service build (r371 through r372n) shipped this exact archive.
# It is adapted from ADE, but it is bundled by NCTC and does not require the
# player's Auto Drive Enhanced mod to be installed.
$trafficRuntimeArchive = Join-Path $projectRoot "source\archive\pc\mod\NCTCTrafficRuntime.archive"
$expectedTrafficRuntimeSha256 = "98701118D1F5A4DA6AC47CA070300EC607012CCAD51E91406FB657B034736A7D"
if (!(Test-Path -LiteralPath $trafficRuntimeArchive)) {
    throw 'Missing required source\archive\pc\mod\NCTCTrafficRuntime.archive.'
}
$trafficRuntimeSha256 = (Get-FileHash -LiteralPath $trafficRuntimeArchive -Algorithm SHA256).Hash
if ($trafficRuntimeSha256 -ne $expectedTrafficRuntimeSha256) {
    throw "Unexpected NCTCTrafficRuntime.archive SHA-256: $trafficRuntimeSha256"
}
New-Item -ItemType Directory -Force (Join-Path $stageRoot "archive\pc\mod") | Out-Null
Copy-Item -LiteralPath $trafficRuntimeArchive -Destination (Join-Path $stageRoot "archive\pc\mod\NCTCTrafficRuntime.archive")

# The dynamic route/line display is now part of the development baseline.
# nctc_service_bus.yaml points at nctc\vehicles\mahir_display.ent, so silently
# packaging without the generated display archive would produce a broken bus.
# Keep the legacy switch parameter for existing local commands, but every
# development package now requires and ships the display archive.
$displayArchive = Join-Path $projectRoot 'tmp\NCTCDisplayPrototype.archive'
if (!(Test-Path -LiteralPath $displayArchive)) {
    throw 'Missing tmp\NCTCDisplayPrototype.archive. Generate the validated dynamic display assets before packaging.'
}
Copy-Item -LiteralPath $displayArchive -Destination (Join-Path $stageRoot 'archive\pc\mod\NCTCDisplayPrototype.archive')

if ($IncludeSurveyRuntime -and (Test-Path -LiteralPath (Join-Path $projectRoot "source\cet\nctc_survey\init.lua"))) {
    New-Item -ItemType Directory -Force (Join-Path $stageRoot "bin\x64\plugins\cyber_engine_tweaks\mods\nctc_survey") | Out-Null
    Copy-Item -Path (Join-Path $projectRoot "source\cet\nctc_survey\*") -Destination (Join-Path $stageRoot "bin\x64\plugins\cyber_engine_tweaks\mods\nctc_survey")
}
if ($IncludeSurveyRuntime -and (Test-Path -LiteralPath (Join-Path $projectRoot "source\cet\nctc_passenger\init.lua"))) {
    New-Item -ItemType Directory -Force (Join-Path $stageRoot "bin\x64\plugins\cyber_engine_tweaks\mods\nctc_passenger") | Out-Null
    Copy-Item -Path (Join-Path $projectRoot "source\cet\nctc_passenger\*") -Destination (Join-Path $stageRoot "bin\x64\plugins\cyber_engine_tweaks\mods\nctc_passenger")
}
Copy-Item -LiteralPath (Join-Path $projectRoot "README.md") -Destination $stageRoot
Copy-Item -LiteralPath (Join-Path $projectRoot "THIRD_PARTY_NOTICES.md") -Destination $stageRoot
if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $archivePath -CompressionLevel Optimal
Write-Host "Package created: $archivePath"
