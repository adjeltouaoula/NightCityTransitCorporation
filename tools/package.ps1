param(
    [string]$Version = "0.2.9-hub-markers",
    [switch]$IncludeSurveyRuntime
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$distRoot = Join-Path $projectRoot "dist"
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
if ($IncludeSurveyRuntime -and (Test-Path -LiteralPath (Join-Path $projectRoot "source\cet\nctc_survey\init.lua"))) {
    New-Item -ItemType Directory -Force (Join-Path $stageRoot "bin\x64\plugins\cyber_engine_tweaks\mods\nctc_survey") | Out-Null
    Copy-Item -Path (Join-Path $projectRoot "source\cet\nctc_survey\*") -Destination (Join-Path $stageRoot "bin\x64\plugins\cyber_engine_tweaks\mods\nctc_survey")
}
Copy-Item -LiteralPath (Join-Path $projectRoot "README.md") -Destination $stageRoot
if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $archivePath -CompressionLevel Optimal
Write-Host "Package created: $archivePath"
