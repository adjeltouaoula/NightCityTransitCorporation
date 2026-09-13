param(
  [string]$GameDir = $env:CYBERPUNK2077_DIR
)

$ErrorActionPreference = 'Stop'

function Resolve-GameDir {
  param([string]$Explicit)
  if (-not [string]::IsNullOrWhiteSpace($Explicit) -and (Test-Path $Explicit)) {
    return (Resolve-Path $Explicit).Path
  }
  $candidates = @(
    'F:\Program Files\GOG Galaxy\Games\Cyberpunk 2077',
    'C:\Program Files (x86)\GOG Galaxy\Games\Cyberpunk 2077',
    'C:\Program Files\GOG Galaxy\Games\Cyberpunk 2077',
    'C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077',
    'C:\Program Files\Steam\steamapps\common\Cyberpunk 2077'
  )
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }
  }
  throw 'Cyberpunk 2077 directory not found. Set CYBERPUNK2077_DIR on the self-hosted runner.'
}

$GameDir = Resolve-GameDir $GameDir
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$NctcSource = Join-Path $RepoRoot 'source\redscript\NCTC'
$Scc = Join-Path $GameDir 'engine\tools\scc.exe'
$GameScripts = Join-Path $GameDir 'r6\scripts'
$VanillaBackup = Join-Path $GameDir 'r6\cache\final.redscripts.bk'
$CompilePaths = Join-Path $GameDir 'red4ext\redscript_paths.txt'

if (-not (Test-Path $Scc)) { throw "REDscript compiler not found: $Scc" }
if (-not (Test-Path $GameScripts)) { throw "Game scripts directory not found: $GameScripts" }
if (-not (Test-Path $NctcSource)) { throw "NCTC REDscript source not found: $NctcSource" }
if (-not (Test-Path $VanillaBackup)) { throw "Vanilla REDscript backup not found: $VanillaBackup" }

$RunnerTemp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
$RunId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { [guid]::NewGuid().ToString('N') }
$Stage = Join-Path $RunnerTemp "nctc-redscript-ci-$RunId"
$StageR6 = Join-Path $Stage 'r6'
$StageScripts = Join-Path $StageR6 'scripts'
$StageCache = Join-Path $StageR6 'cache'
$StageBundle = Join-Path $StageCache 'final.redscripts'
$StageBackup = Join-Path $StageCache 'final.redscripts.bk'
$LogPath = Join-Path $Stage 'redscript-ci.log'

if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Path $StageScripts -Force | Out-Null
New-Item -ItemType Directory -Path $StageCache -Force | Out-Null
Copy-Item (Join-Path $GameScripts '*') $StageScripts -Recurse -Force
$StagedNctc = Join-Path $StageScripts 'NCTC'
if (Test-Path $StagedNctc) { Remove-Item $StagedNctc -Recurse -Force }
Copy-Item $NctcSource $StagedNctc -Recurse -Force
Copy-Item $VanillaBackup $StageBackup -Force

$args = @('-compile', $StageScripts, $StageBundle, '-Wnone', '-threads', '4', '-no-testonly', '-no-breakpoint', '-no-exec', '-no-debug', '-profile=off', '-optimize')
if (Test-Path $CompilePaths) {
  $args += '-compilePathsFile'
  $args += $CompilePaths
}

Write-Host "Running real REDscript compiler: $Scc"
$compilerOutput = & $Scc @args 2>&1
$exitCode = $LASTEXITCODE
$compilerOutput | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
$text = ($compilerOutput | Out-String)
if ($exitCode -ne 0) { throw "scc.exe exited with code $exitCode. See $LogPath" }
if ($text -match '\[ERROR\s*-|Compilation error|compilation has failed|REDScript compilation has failed') { throw "REDscript semantic compilation reported errors. See $LogPath" }
if (-not (Test-Path $StageBundle)) { throw "Compiler produced no final.redscripts output. See $LogPath" }
Write-Host 'REDscript CI PASSED.'
if ($env:GITHUB_ENV) { "NCTC_REDSCRIPT_CI_LOG=$LogPath" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append }
