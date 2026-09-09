# Dedicated copy: do not change NCART or any other world screen.
$flatMesh=Read-GameAsset 'base\environment\decoration\advertising\holograms\common\common_holograms_a.mesh'
$entry=$flatMesh.RootChunk.MaterialEntries | Where-Object {$_.Name.ToString() -eq 'ncart_door_screen'}
if(!$entry -or !$entry.IsLocalInstance){throw 'NCART material not found'}
$material=$flatMesh.RootChunk.LocalMaterialBuffer.Materials[[int]$entry.Index.ToString()]
$changed=0
foreach($value in $material.Values){
 if($value.Key.ToString() -eq 'LayersSeparation'){$value.Value=[WolvenKit.RED4.Types.CFloat][single]0;$changed++}
 if($value.Key.ToString() -eq 'IntensityPerLayer'){
  $value.Value.Y=[WolvenKit.RED4.Types.CFloat][single]0
  $value.Value.Z=[WolvenKit.RED4.Types.CFloat][single]0
  $value.Value.W=[WolvenKit.RED4.Types.CFloat][single]0
  $changed++
 }
}
if($changed -ne 2){throw 'Layer parameters not found'}
$path=Join-Path $assets 'nctc\ui\display_screen.mesh'
New-Item -ItemType Directory -Force (Split-Path $path -Parent)|Out-Null
$stream=[IO.File]::Create($path)
try{$writer=[WolvenKit.RED4.Archive.IO.CR2WWriter]::new($stream);$writer.WriteFile($flatMesh)}finally{$stream.Dispose()}
$stream=[IO.File]::OpenRead($path)
try{
 $reader=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($stream);$check=$null
 if($reader.ReadFile([ref]$check,$true).ToString() -ne 'NoError'){throw 'Flat screen round-trip failed'}
 $saved=$check.RootChunk.LocalMaterialBuffer.Materials[[int]$entry.Index.ToString()]
 foreach($v in $saved.Values){if($v.Key.ToString() -in @('LayersSeparation','IntensityPerLayer')){Write-Output "Flat screen verified: $($v.Key)=$($v.Value)"}}
}finally{$stream.Dispose()}
