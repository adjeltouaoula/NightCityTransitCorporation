# Single-variable probe: a private NCTC appearance with kinematic door physics.
$ErrorActionPreference='Stop'
$wk='F:\Program Files\GOG Galaxy\Games\my mods\WolvenKit-8.20.0.zip 2201 8.20.0 2026-08-06T08-14Z xNHtNXgDX'
$game='F:\Program Files\GOG Galaxy\Games\Cyberpunk 2077'
$project=Split-Path $PSScriptRoot -Parent
$assets=Join-Path $project 'tmp\door-test-assets'
Get-ChildItem $wk -Filter '*.dll' | ForEach-Object {try{[Reflection.Assembly]::LoadFrom($_.FullName)|Out-Null}catch{}}
if(![WolvenKit.Core.Compression.Oodle]::Load("$game\bin\x64\oo2ext_7_win64.dll")){throw 'Compression unavailable'}
$hash=[WolvenKit.Common.Services.HashService]::new();$hash.Load()
$reader=[WolvenKit.RED4.Archive.IO.ArchiveReader]::new();$archive=$null
$null=$reader.ReadArchive("$game\archive\pc\mod\NightCityTrafficOverhaul.archive",$hash,[ref]$archive)
function Read-Source([string]$path){
 $id=[WolvenKit.Common.FNV1A.FNV1A64HashAlgorithm]::HashString($path)
 if(!$archive.Files.ContainsKey($id)){throw "Missing $path"}
 $s=[IO.MemoryStream]::new()
 try{$archive.ExtractFile($archive.Files[$id],$s);$s.Position=0;$r=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($s);$f=$null;if($r.ReadFile([ref]$f,$true).ToString() -ne 'NoError'){throw 'Parse failed'};return $f}finally{$s.Dispose()}
}
function Write-Checked($f,[string]$relative){
 $path=Join-Path $assets $relative
 New-Item -ItemType Directory -Force (Split-Path $path -Parent)|Out-Null
 $s=[IO.File]::Create($path)
 try{$w=[WolvenKit.RED4.Archive.IO.CR2WWriter]::new($s);$w.WriteFile($f)}finally{$s.Dispose()}
 $s=[IO.File]::OpenRead($path)
 try{$r=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($s);$check=$null;if($r.ReadFile([ref]$check,$true).ToString() -ne 'NoError'){throw 'Roundtrip failed'};return $check}finally{$s.Dispose()}
}
$app=Read-Source 'night_city_traffic_overhaul\appearances\transport\mahir_mt28_basic.app'
$components=$app.RootChunk.Appearances[0].GetValue().Components
$door=@($components|Where-Object {$_.Name.ToString() -eq 'door'})
$step=$components|Where-Object {$_.Name.ToString() -eq 'entrance_step'}
if($door.Count -ne 1 -or $door[0].SimulationType.ToString() -ne 'Static' -or $step.SimulationType.ToString() -ne 'Kinematic'){throw 'Unexpected source; do not guess'}
$door[0].SimulationType=$step.SimulationType
$checked=Write-Checked $app 'nctc\door_test\mahir.app'
$saved=$checked.RootChunk.Appearances[0].GetValue().Components|Where-Object {$_.Name.ToString() -eq 'door'}
if($saved.SimulationType.ToString() -ne 'Kinematic' -or $saved.UseResourceSimulationType.ToString() -ne 'False'){throw 'Door override not preserved'}
$entity=Read-Source 'night_city_traffic_overhaul\entities\transport\v_mahir_mt28_coach_basic_01.ent'
foreach($appearance in $entity.RootChunk.Appearances){$appearance.AppearanceResource=[WolvenKit.RED4.Types.CResourceAsyncReference[WolvenKit.RED4.Types.appearanceAppearanceResource]]::new('nctc\door_test\mahir.app')}
$checked=Write-Checked $entity 'nctc\door_test\mahir.ent'
foreach($a in $checked.RootChunk.Appearances){if($a.AppearanceResource.DepotPath.ToString() -ne 'nctc\door_test\mahir.app'){throw 'Appearance reference lost'}}
$path=Join-Path $project 'tmp\NCTCDoorCollisionTest.archive'
$s=[IO.File]::Create($path)
try{$w=[WolvenKit.RED4.Archive.IO.ArchiveWriter]::new($hash,$null);if(!$w.WriteArchive([IO.DirectoryInfo]::new($assets),$s)){throw 'Archive failed'}}finally{$s.Dispose()}
Write-Output "Verified door test: $path; Static -> Kinematic; unchanged collider, filter and animation bindings."
