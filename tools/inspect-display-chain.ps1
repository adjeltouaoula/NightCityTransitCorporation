param([switch]$Font, [string]$Asset, [switch]$Panels, [switch]$Transforms, [switch]$Signs, [int]$SignChunk=6)
$ErrorActionPreference='Stop'
$wk='F:\Program Files\GOG Galaxy\Games\my mods\WolvenKit-8.20.0.zip 2201 8.20.0 2026-08-06T08-14Z xNHtNXgDX'
$game='F:\Program Files\GOG Galaxy\Games\Cyberpunk 2077'
Get-ChildItem $wk -Filter '*.dll' | ForEach-Object {try{[Reflection.Assembly]::LoadFrom($_.FullName)|Out-Null}catch{}}
$null=[WolvenKit.Core.Compression.Oodle]::Load("$game\bin\x64\oo2ext_7_win64.dll")
$hash=[WolvenKit.Common.Services.HashService]::new(); $hash.Load()
$ar=[WolvenKit.RED4.Archive.IO.ArchiveReader]::new()
function Read-Asset([string]$path){
 $id=[WolvenKit.Common.FNV1A.FNV1A64HashAlgorithm]::HashString($path)
 foreach($af in @(Get-ChildItem "$game\archive\pc\mod" -Filter 'NightCityTrafficOverhaul.archive') + @(Get-ChildItem "$game\archive\pc\content" -Filter '*.archive')){
  $a=$null; $null=$ar.ReadArchive($af.FullName,$hash,[ref]$a)
  if(!$a.Files.ContainsKey($id)){continue}
  $s=[IO.MemoryStream]::new()
  try{$a.ExtractFile($a.Files[$id],$s); $s.Position=0; $r=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($s); $f=$null; $result=$r.ReadFile([ref]$f,$true); Write-Host "Read $path from $($af.Name): $result bytes=$($s.Length)"; if($result.ToString() -ne 'NoError'){throw "Read failed: $result"}; return $f}finally{$s.Dispose()}
 }
 throw "Missing $path"
}
if($Transforms){
 $app=Read-Asset 'night_city_traffic_overhaul\appearances\transport\mahir_mt28_basic.app'
 $metro=Read-Asset 'base\open_world\metro\ue_metro\entities\ue_metro_train.ent'
 $components=@($app.RootChunk.Appearances[0].GetValue().Components | Where-Object {$_.Name.ToString() -in @('body_01','interior_01')}) + @($metro.RootChunk.Components | Where-Object {$_.Name.ToString() -eq 'screen5558'})
 foreach($c in $components){
  "COMPONENT $($c.Name)"
  foreach($axis in @('X','Y','Z')){"POSITION $axis"; $c.LocalTransform.Position.$axis | Format-List *}
  $c.LocalTransform.Position | Format-List *
  $c.LocalTransform.Orientation | Format-List *
  $c.VisualScale | Format-List *
  $c.ParentTransform.GetValue() | Format-List *
 }
 $mesh=Read-Asset 'base\environment\decoration\advertising\holograms\common\common_holograms_a.mesh'
 $mesh.RootChunk.BoundingBox | Format-List *
 exit
}
if($Asset){
 $assetFile=Read-Asset $Asset
 if($Asset.EndsWith('.mt')){
  foreach($set in $assetFile.RootChunk.Parameters){foreach($h in $set){$p=$h.GetValue();$p|Format-List *}}
  exit
 }
 if($Signs){
  $model=[WolvenKit.Modkit.RED4.Tools.MeshTools]::GetModel($assetFile,$false,$false,[UInt64]::MaxValue,$false,$false)
  if($SignChunk -lt 0){
   foreach($m in $model.LogicalMeshes){
    if($m.Name -notmatch '_LOD_1$'){continue}
    $points=@($m.Primitives[0].GetVertexAccessor('POSITION').AsVector3Array() | Where-Object {$_.Y -gt 1.75 -and $_.Z -lt -4.8})
    if(!$points.Count){continue}
    "$($m.Name) count=$($points.Count)"
    foreach($axis in @('X','Y','Z')){$s=$points|Measure-Object $axis -Minimum -Maximum;"$axis $($s.Minimum) $($s.Maximum)"}
   }
   exit
  }
  if($SignChunk -eq -1){
   foreach($m in $model.LogicalMeshes){
    if($m.Name -notmatch '_LOD_1$'){continue}
    $points=@($m.Primitives[0].GetVertexAccessor('POSITION').AsVector3Array() | Where-Object {$_.Z -lt -4.8 -and $_.Y -gt 1.4 -and $_.X -lt -0.4})
    if($points.Count -eq 0){continue}
    "$($m.Name) count=$($points.Count)"
    foreach($axis in @('X','Y','Z')){$s=$points|Measure-Object $axis -Minimum -Maximum;"$axis $($s.Minimum) $($s.Maximum)"}
   }
   exit
  }
  $part=$model.LogicalMeshes | Where-Object {$_.Name -eq ('submesh_'+$SignChunk.ToString('00')+'_LOD_1')}
  $ps=$part.Primitives[0].GetVertexAccessor('POSITION').AsVector3Array()
  $ns=$part.Primitives[0].GetVertexAccessor('NORMAL').AsVector3Array()
  $normalGroups=@{}
  for($ni=0;$ni -lt $ps.Count;$ni++){
   if($ps[$ni].Y -lt 1.75){continue}
   $p=$ps[$ni];$n=$ns[$ni]
   $nk="$(if($p.Z -lt -4.8){'front'}elseif($p.Z -gt 4.8){'rear'}else{'side'+[Math]::Sign($p.X)}) $([Math]::Round($n.X,4)),$([Math]::Round($n.Y,4)),$([Math]::Round($n.Z,4))"
   $normalGroups[$nk]++
  }
  $normalGroups.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 12 | ForEach-Object {"NORMAL $($_.Key) count=$($_.Value)"}
  $groups=@{}
  for($i=0;$i -lt $ps.Count;$i++){
   $v=$ps[$i];if($v.Y -lt 1.75){continue}
   $key=if($v.Z -lt -4.8){'front-z'+[Math]::Round($v.Z,1)}elseif($v.Z -gt 4.8){'rear'}else{'side'+[Math]::Sign($v.X)}
   if(!$groups.ContainsKey($key)){$groups[$key]=[Collections.Generic.List[object]]::new()}
   $groups[$key].Add($v)
  }
  foreach($key in $groups.Keys){
   "GROUP $key"
   foreach($axis in @('X','Y','Z')){$s=$groups[$key]|Measure-Object $axis -Minimum -Maximum;"$axis $($s.Minimum) $($s.Maximum)"}
   $points=$groups[$key]; $meanY=($points|Measure-Object Y -Average).Average
   foreach($axis in @('X','Z')){
    $mean=($points|Measure-Object $axis -Average).Average; $cov=0.0; $var=0.0
    foreach($v in $points){$cov+=($v.Y-$meanY)*($v.$axis-$mean);$var+=($v.Y-$meanY)*($v.Y-$meanY)}
    "slope $axis/Y = $($cov/$var)"
   }
  }
  exit
 }
 if($Asset.EndsWith('.mesh')){
  if($Panels){
   $blob=$assetFile.RootChunk.RenderResourceBlob.GetValue()
   $blob | Format-List *
   $blob.Header.RenderChunkInfos[6].ChunkIndices | Format-List *
   $blob.Header.RenderChunkInfos[6].ChunkVertices | Format-List *
   $model=[WolvenKit.Modkit.RED4.Tools.MeshTools]::GetModel($assetFile,$false,$false,[UInt64]::MaxValue,$false,$false)
   foreach($m in $model.LogicalMeshes){
    if($m.Name -notmatch '^submesh_0[46]_LOD_1$'){continue}
    foreach($p in $m.Primitives){
     $pos=$p.GetVertexAccessor('POSITION').AsVector3Array()
     $normal=$p.GetVertexAccessor('NORMAL').AsVector3Array()
     $groups=@{}
     for($j=0;$j -lt $pos.Count;$j++){
      $v=$pos[$j]; if($v.Y -lt 1.75){continue}
      $key= if($v.Z -lt -4.8){'front'}elseif($v.Z -gt 4.8){'rear'}elseif($v.X -lt 0){'negativeX'}else{'positiveX'}
      if(!$groups.ContainsKey($key)){$groups[$key]=[Collections.Generic.List[object]]::new()}
      $groups[$key].Add($v)
     }
     foreach($key in $groups.Keys){
      $points=$groups[$key]; "$($m.Name) $key count=$($points.Count)"
      foreach($axis in @('X','Y','Z')){$stats=$points | Measure-Object -Property $axis -Minimum -Maximum; "$axis min=$($stats.Minimum) max=$($stats.Maximum)"}
     }
    }
   }
   exit
   $assetFile.RootChunk.RenderResourceBlob.GetValue().Header | Format-List *
   $assetFile.RootChunk.RenderResourceBlob.GetValue().Header.RenderChunkInfos | Select-Object -First 8 | Format-List *
   exit
   $model=[WolvenKit.Modkit.RED4.Tools.MeshTools]::GetModel($assetFile,$false,$false,[UInt64]::MaxValue,$false,$false)
   $materials=$assetFile.RootChunk.Appearances[0].GetValue().ChunkMaterials
   foreach($m in $model.LogicalMeshes){foreach($p in $m.Primitives){
    $ps=$p.GetVertexAccessor('POSITION').AsVector3Array()
    if($ps.Count -gt 100){continue}
    "SMALL $($m.Name) vertices=$($ps.Count)"
    $ps | ForEach-Object ToString
   }}
   exit
   for($i=0;$i -lt [Math]::Min(19,$model.LogicalMeshes.Count);$i++){
    if($materials[$i].ToString() -notmatch 'busnumber|scrolling'){continue}
    "PANEL CHUNK $i $($materials[$i])"
    $meshPart=$model.LogicalMeshes | Where-Object {$_.Name -match ('^submesh_0?'+$i+'_')}
    foreach($p in $meshPart.Primitives){
     $pos=$p.GetVertexAccessor('POSITION').AsVector3Array()
     $norm=$p.GetVertexAccessor('NORMAL').AsVector3Array()
     for($j=0;$j -lt $pos.Count;$j++){"v$j $($pos[$j]) normal=$($norm[$j])"}
    }
   }
   exit
  }
  foreach($a in $assetFile.RootChunk.Appearances){$def=$a.GetValue(); "Appearance $($def.Name)";for($i=0;$i -lt $def.ChunkMaterials.Count;$i++){"$i : $($def.ChunkMaterials[$i])"}}
  foreach($mi in $assetFile.RootChunk.LocalMaterialBuffer.Materials){$mi | Format-List BaseMaterial; foreach($v in $mi.Values){"$($v.Key)=$($v.Value)"}}
  exit
 }
 $assetFile.RootChunk | Format-List *
 foreach($c in $assetFile.RootChunk.Components){$c | Format-List Name,Mesh,MeshAppearance,ChunkMask,LocalTransform}
 foreach($a in $assetFile.RootChunk.Appearances){
  $a | Format-List *
  if($a.GetType().Name -like 'CHandle*'){
   $a.GetValue() | Format-List *
   foreach($c in $a.GetValue().Components){if($c.Mesh){$c | Format-List Name,Mesh,MeshAppearance,ChunkMask,LocalTransform}}
  }
 }
 exit
}
if($Font){
 $fontFile=Read-Asset 'base\gameplay\gui\fonts\raj\raj.inkfontfamily'
 $fontFile.RootChunk | Format-List *
 foreach($style in $fontFile.RootChunk.Styles){$style | Format-List *}
 exit
}
$mesh=Read-Asset 'base\environment\decoration\advertising\holograms\common\common_holograms_a.mesh'
$mesh.RootChunk | Format-List BoundingBox
$model=[WolvenKit.Modkit.RED4.Tools.MeshTools]::GetModel($mesh,$false,$false,[UInt64]::MaxValue,$false,$false)
foreach($m in $model.LogicalMeshes){foreach($p in $m.Primitives){
 $pos=$p.GetVertexAccessor('POSITION').AsVector3Array()
 "Mesh=$($m.Name) vertices=$($pos.Count)"
 $pos | Select-Object -First 8 | ForEach-Object ToString
 $p.GetVertexAccessor('TEXCOORD_0').AsVector2Array() | Select-Object -First 8 | ForEach-Object ToString
 $p.GetVertexAccessor('NORMAL').AsVector3Array() | Select-Object -First 2 | ForEach-Object ToString
}}
foreach($h in $mesh.RootChunk.Appearances){
 $a=$h.GetValue()
 if($a.Name.ToString() -eq 'ncart_door_screen'){
  $a | Format-List *
  foreach($mat in $a.ChunkMaterials){
   $entry=$mesh.RootChunk.MaterialEntries | Where-Object {$_.Name.ToString() -eq $mat.ToString()}
   $entry | Format-List *
   if($entry.IsLocalInstance.ToString() -eq 'True'){
    $mi=$mesh.RootChunk.LocalMaterialBuffer.Materials[[int]$entry.Index.ToString()]
    $mi | Format-List *
    foreach($v in $mi.Values){"$($v.Key)=$($v.Value)"}
   }
  }
 }
}
exit
$metro=Read-Asset 'base\open_world\metro\ue_metro\entities\ue_metro_train.ent'
$w=$metro.RootChunk.Components | Where-Object {$_.Name.ToString() -eq 'dataTerm_ui5441'}
$w | Format-List *
$ui=Read-Asset $w.WidgetResource.DepotPath.ToString()
$ui.RootChunk | Format-List *
$ui | Format-List *
$ui.RootChunk.GetDynamicProperties() | Format-List *
foreach($embedded in $ui.EmbeddedFiles){$embedded | Format-List *}
foreach($item in $ui.RootChunk.LibraryItems){
 $item | Format-List Name,PackageData
 $instance=$item.PackageData.Data.RootChunk
 $instance | Format-List *
 if($instance.GameController){$instance.GameController.GetValue() | Format-List *}
}
