param([string]$Asset='night_city_traffic_overhaul\entities\transport\v_mahir_mt28_coach_basic_01.ent', [string]$ComponentPattern='door|coll|phys')
$ErrorActionPreference='Stop'
$wk='F:\Program Files\GOG Galaxy\Games\my mods\WolvenKit-8.20.0.zip 2201 8.20.0 2026-08-06T08-14Z xNHtNXgDX'
$game='F:\Program Files\GOG Galaxy\Games\Cyberpunk 2077'
Get-ChildItem $wk -Filter '*.dll' | ForEach-Object {try{[Reflection.Assembly]::LoadFrom($_.FullName)|Out-Null}catch{}}
$null=[WolvenKit.Core.Compression.Oodle]::Load("$game\bin\x64\oo2ext_7_win64.dll")
$hash=[WolvenKit.Common.Services.HashService]::new();$hash.Load()
$reader=[WolvenKit.RED4.Archive.IO.ArchiveReader]::new()
$id=[WolvenKit.Common.FNV1A.FNV1A64HashAlgorithm]::HashString($Asset)
foreach($af in @(Get-ChildItem "$game\archive\pc\mod" -Filter '*.archive') + @(Get-ChildItem "$game\archive\pc\content" -Filter '*.archive')){
 $ar=$null;$null=$reader.ReadArchive($af.FullName,$hash,[ref]$ar)
 if(!$ar.Files.ContainsKey($id)){continue}
 Write-Output "SOURCE $($af.FullName) ASSET $Asset"
 $stream=[IO.MemoryStream]::new()
 try{
  $ar.ExtractFile($ar.Files[$id],$stream);$stream.Position=0
  $cr=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($stream);$file=$null
  if($cr.ReadFile([ref]$file,$true).ToString() -ne 'NoError'){throw 'Cannot parse asset'}
  $root=$file.RootChunk
  if($Asset.EndsWith('.mesh')){
   $root | Format-List *
   foreach($bone in $root.BoneNames){"BONE $bone"}
   $model=[WolvenKit.Modkit.RED4.Tools.MeshTools]::GetModel($file,$false,$false,[UInt64]::MaxValue,$false,$false)
   $groups=@{}
   foreach($m in $model.LogicalMeshes){
    if($m.Name -notmatch '_LOD_1$'){continue}
    foreach($prim in $m.Primitives){
     $ps=$prim.GetVertexAccessor('POSITION').AsVector3Array()
     $js=$prim.GetVertexAccessor('JOINTS_0').AsVector4Array()
     $ws=$prim.GetVertexAccessor('WEIGHTS_0').AsVector4Array()
     for($i=0;$i -lt $ps.Count;$i++){
      foreach($axis in @('X','Y','Z','W')){
       if($ws[$i].$axis -lt 0.5){continue}
       $bone=$root.BoneNames[[int]$js[$i].$axis].ToString()
       if(!$groups.ContainsKey($bone)){$groups[$bone]=[Collections.Generic.List[object]]::new()}
       $groups[$bone].Add($ps[$i])
      }
     }
    }
   }
   foreach($bone in $groups.Keys){
    "GEOMETRY $bone (glTF X=side,Y=up,Z=rear)"
    foreach($axis in @('X','Y','Z')){$b=$groups[$bone]|Measure-Object $axis -Minimum -Maximum;"$axis $($b.Minimum) $($b.Maximum)"}
   }
   foreach($param in $root.Parameters){
    $value=$param.GetValue();$value | Format-List *
    if($value.PhysicsData){
     $physics=$value.PhysicsData.GetValue();$physics | Format-List *
     foreach($body in $physics.Bodies){
      $b=$body.GetValue();$b | Format-List *
      $b.Params | Format-List *
      $b.LocalToModel | Format-List *
      foreach($shape in $b.CollisionShapes){
       $s=$shape.GetValue();$s | Format-List *
       $s.FilterData.GetValue() | Format-List *
       $s.LocalToBody | Format-List *
      }
     }
    }
   }
   continue
  }
  $root | Format-List Includes,Appearances
  $components=@($root.Components)
  foreach($app in $root.Appearances){if($app.PSObject.Methods['GetValue']){$components+=@($app.GetValue().Components)}}
  foreach($c in $components){
   if(!$c){continue}
   "COMPONENT $($c.Name) TYPE $($c.GetType().Name)"
   if($c.Name.ToString() -match $ComponentPattern){
    $c | Format-List *
    if($c.ParentTransform){$c.ParentTransform.GetValue() | Format-List *}
    if($c.FilterData){$c.FilterData.GetValue() | Format-List *}
    foreach($shape in $c.CollisionShapes){$shape.GetValue() | Format-List *}
   }
  }
 }finally{$stream.Dispose()}
}
