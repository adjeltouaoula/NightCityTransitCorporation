param(
  [string]$WolvenKitPath='F:\Program Files\GOG Galaxy\Games\my mods\WolvenKit-8.20.0.zip 2201 8.20.0 2026-08-06T08-14Z xNHtNXgDX',
  [string]$GamePath='F:\Program Files\GOG Galaxy\Games\Cyberpunk 2077'
)
$ErrorActionPreference='Stop'
Get-ChildItem -LiteralPath $WolvenKitPath -Filter '*.dll' | ForEach-Object { try { [Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
if(![WolvenKit.Core.Compression.Oodle]::Load((Join-Path $GamePath 'bin\x64\oo2ext_7_win64.dll'))){ throw 'Could not load game compression library' }
$hash=[WolvenKit.Common.Services.HashService]::new(); $hash.Load()
$archiveReader=[WolvenKit.RED4.Archive.IO.ArchiveReader]::new()
function Read-GameAsset([string]$asset) {
  $assetId=[WolvenKit.Common.FNV1A.FNV1A64HashAlgorithm]::HashString($asset)
  foreach($archiveFile in Get-ChildItem (Join-Path $GamePath 'archive\pc\content') -Filter '*.archive') {
    $archive=$null; $null=$archiveReader.ReadArchive($archiveFile.FullName,$hash,[ref]$archive)
    if(!$archive.Files.ContainsKey($assetId)){ continue }
    $input=[IO.MemoryStream]::new()
    try {
      $archive.ExtractFile($archive.Files[$assetId],$input); $input.Position=0
      $reader=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($input); $file=$null
      if(($reader.ReadFile([ref]$file,$true)).ToString() -ne 'NoError'){ throw "Could not read $asset" }
      return $file
    } finally { $input.Dispose() }
  }
  throw "Could not find $asset"
}
$assets=@(
  'base\vehicles\special\v_mahir_mt28_coach\entities\v_mahir_mt28_coach__ext01_interior_01.ent',
  'base\open_world\metro\ue_metro\entities\ue_metro_train.ent'
)
foreach($asset in $assets){
  Write-Output "ASSET $asset"
  $file=Read-GameAsset $asset
  foreach($component in $file.RootChunk.Components){
    $name=$component.Name.ToString(); $type=$component.GetType().Name
    $pos=$component.LocalTransform.Position
    $rot=$component.LocalTransform.Orientation
    $px=[single]$pos.X
    $py=[single]$pos.Y
    $pz=[single]$pos.Z
    $extra=''
    if($component.PSObject.Properties.Name -contains 'Mesh'){
      $extra=" mesh=$($component.Mesh.DepotPath)"
      if($component.PSObject.Properties.Name -contains 'VisualScale'){$extra += " scale=($($component.VisualScale.X),$($component.VisualScale.Y),$($component.VisualScale.Z))"}
    }
    Write-Output ("{0,-55} {1,-38} pos=({2},{3},{4}) rot=({5},{6},{7},{8}){9}" -f $name,$type,$px,$py,$pz,$rot.I,$rot.J,$rot.K,$rot.R,$extra)
  }
}
