param([string]$GamePath = "F:\Program Files\GOG Galaxy\Games\Cyberpunk 2077")

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path $projectRoot "tmp\compile-root"
$scriptsRoot = Join-Path $tempRoot "r6\scripts"
$cacheRoot = Join-Path $tempRoot "r6\cache"

if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $scriptsRoot "NCTC"), (Join-Path $scriptsRoot "Codeware"), (Join-Path $scriptsRoot "ModSettings"), (Join-Path $scriptsRoot "AutoDriveEnhanced"), $cacheRoot | Out-Null
Copy-Item -Path (Join-Path $projectRoot "source\redscript\NCTC\*.reds") -Destination (Join-Path $scriptsRoot "NCTC")
Copy-Item -LiteralPath (Join-Path $GamePath "r6\cache\final.redscripts") -Destination $cacheRoot
Copy-Item -LiteralPath (Join-Path $GamePath "red4ext\plugins\Codeware\Scripts\Codeware.Global.reds") -Destination (Join-Path $scriptsRoot "Codeware\Codeware.Global.reds")
Copy-Item -LiteralPath (Join-Path $GamePath "red4ext\plugins\Codeware\Scripts\Codeware.Localization.reds") -Destination (Join-Path $scriptsRoot "Codeware\Codeware.Localization.reds")
# Auto Drive Enhanced remains an external runtime dependency. Its scripts are
# copied only into the temporary compiler root, never into the NCTC package.
Copy-Item -LiteralPath (Join-Path $GamePath "red4ext\plugins\mod_settings\packed.reds") -Destination (Join-Path $scriptsRoot "ModSettings\ModSettings.reds")
Copy-Item -Path (Join-Path $GamePath "r6\scripts\auto_drive_enhanced\*.reds") -Destination (Join-Path $scriptsRoot "AutoDriveEnhanced")
# Experimental ADE-owned route branch: replace only the source file that adds
# NCTC's explicit-destination entry point. This is never used by the release
# baseline and remains an ADE dependency.
$nctcAdePatch = Join-Path $projectRoot "source\vendor\auto_drive_enhanced\driving_ai.reds"
if (Test-Path -LiteralPath $nctcAdePatch) {
    Copy-Item -LiteralPath $nctcAdePatch -Destination (Join-Path $scriptsRoot "AutoDriveEnhanced\driving_ai.reds") -Force
}

& (Join-Path $GamePath "engine\tools\scc.exe") -compile $scriptsRoot -customCacheDir (Join-Path $cacheRoot "modded")
if ($LASTEXITCODE -ne 0) { throw "Redscript compilation failed with exit code $LASTEXITCODE." }
