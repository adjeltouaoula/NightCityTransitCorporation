# Called from generate-display-bus.ps1 after WolvenKit and Read-GameAsset load.
$ErrorActionPreference='Stop'
foreach($target in @(
 @{Source='v_mahir_mt28_coach__ext01_body_01.mesh'; Output='mahir_display_body.mesh'},
 @{Source='v_mahir_mt28_coach__int01_interior_01.mesh'; Output='mahir_display_interior.mesh'}
)){
$meshFile=Read-GameAsset ('base\vehicles\special\v_mahir_mt28_coach\entities\meshes\'+$target.Source)
$blob=$meshFile.RootChunk.RenderResourceBlob.GetValue()
$bytes=$blob.RenderBuffer.Buffer.GetBytes()
$model=[WolvenKit.Modkit.RED4.Tools.MeshTools]::GetModel($meshFile,$false,$false,[UInt64]::MaxValue,$false,$false)
$materials=$meshFile.RootChunk.Appearances[0].GetValue().ChunkMaterials
$removed=0
for($i=0;$i -lt $materials.Count;$i++){
  if($materials[$i].ToString() -ne 'fake_light_busnumber'){continue}
  $chunk=$blob.Header.RenderChunkInfos[$i]
  if($chunk.ChunkIndices.Pe.ToString() -ne 'IBCT_IndexUShort'){throw 'Unexpected index format'}
  $part=$model.LogicalMeshes | Where-Object {$_.Name -match ('^submesh_'+$i.ToString('00')+'_')}
  if(!$part -or $part.Primitives.Count -ne 1){throw "Missing mesh chunk $i"}
  $positions=$part.Primitives[0].GetVertexAccessor('POSITION').AsVector3Array()
  $offset=[int]$blob.Header.IndexBufferOffset.ToString()+[int]$chunk.ChunkIndices.TeOffset.ToString()
  $count=[int]$chunk.NumIndices.ToString()
  $chunkRemoved=0
  for($j=0;$j -lt $count;$j+=3){
    $inside=$true
    for($k=0;$k -lt 3;$k++){
      $index=[BitConverter]::ToUInt16($bytes,$offset+2*($j+$k))
      if($index -ge $positions.Count){throw 'Index decoding mismatch'}
      # Exported mesh axes: X lateral, Y vertical, Z rearward.
      $v=$positions[$index]
      # Only the upper destination/number surfaces of this material.
      # Entrance/exit lettering below this height remains untouched.
      $frontNumber = $target.Source -like '*ext01_body*' -and $v.X -gt -0.96 -and $v.X -lt -0.57 -and $v.Z -gt -5.40 -and $v.Z -lt -5.37 -and $v.Y -gt 1.70
      if($v.Y -le 1.75 -and !$frontNumber){$inside=$false}
    }
    if($inside){
      # Degenerate only these sign triangles; preserve every other index.
      for($k=1;$k -lt 3;$k++){
        $bytes[$offset+2*($j+$k)]=$bytes[$offset+2*$j]
        $bytes[$offset+2*($j+$k)+1]=$bytes[$offset+2*$j+1]
      }
      $chunkRemoved++
    }
  }
  if($chunkRemoved -eq 0){throw "No lateral sign triangles found in chunk $i"}
  $removed+=$chunkRemoved
  Write-Output "$($target.Source): chunk $i replaced $chunkRemoved upper-sign triangles"
}
if($removed -eq 0){throw 'No signs replaced'}
$blob.RenderBuffer.Buffer.SetBytes($bytes)
function Write-DisplayAsset($resource,[string]$relative){
  $destination=Join-Path $assets $relative
  New-Item -ItemType Directory -Force (Split-Path $destination -Parent)|Out-Null
  $stream=[IO.File]::Create($destination)
  try{$writer=[WolvenKit.RED4.Archive.IO.CR2WWriter]::new($stream);$writer.WriteFile($resource)}finally{$stream.Dispose()}
  $stream=[IO.File]::OpenRead($destination)
  try{
    $reader=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($stream);$check=$null
    if($reader.ReadFile([ref]$check,$true).ToString() -ne 'NoError'){throw "Invalid asset $relative"}
    if($relative.EndsWith('.app')){
      $body=$check.RootChunk.Appearances[0].GetValue().Components | Where-Object {$_.Name.ToString() -eq 'body_01'}
      if($body.Mesh.DepotPath.ToString() -ne 'nctc\vehicles\mahir_display_body.mesh'){throw 'Custom body link lost during serialization'}
    }
    if($relative.EndsWith('.mesh')){
      $saved=$check.RootChunk.RenderResourceBlob.GetValue().RenderBuffer.Buffer.GetBytes()
      $sha=[Security.Cryptography.SHA256]::Create()
      try{if([Convert]::ToBase64String($sha.ComputeHash($saved)) -ne [Convert]::ToBase64String($sha.ComputeHash($bytes))){throw 'Modified mesh buffer did not round-trip'}}finally{$sha.Dispose()}
    }
  }finally{$stream.Dispose()}
}
Write-DisplayAsset $meshFile ('nctc\vehicles\'+$target.Output)
}
$appearanceFile=Read-GameAsset 'night_city_traffic_overhaul\appearances\transport\mahir_mt28_basic.app'
$replaced=0
foreach($a in $appearanceFile.RootChunk.Appearances){foreach($c in $a.GetValue().Components){
  if($c.Name.ToString() -eq 'body_01'){
    $c.Mesh=[WolvenKit.RED4.Types.CResourceAsyncReference[WolvenKit.RED4.Types.CMesh]]::new('nctc\vehicles\mahir_display_body.mesh')
    $replaced++
  }
  if($c.Name.ToString() -eq 'interior_01'){
    $c.Mesh=[WolvenKit.RED4.Types.CResourceAsyncReference[WolvenKit.RED4.Types.CMesh]]::new('nctc\vehicles\mahir_display_interior.mesh')
    $replaced++
  }
}}
if($replaced -ne 2){throw 'Unexpected body/interior component count'}
Write-DisplayAsset $appearanceFile 'nctc\vehicles\mahir_display.app'
