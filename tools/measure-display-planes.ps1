# Run in the generator scope: Read-GameAsset and Add-DisplayPair are required.
# WolvenKit exports glTF (X,Z,-Y); convert back to vehicle/Base coordinates.
function Get-SignPoints([string]$asset) {
  $source=Read-GameAsset $asset
  $model=[WolvenKit.Modkit.RED4.Tools.MeshTools]::GetModel($source,$false,$false,[UInt64]::MaxValue,$false,$false)
  $part=$model.LogicalMeshes | Where-Object {$_.Name -eq 'submesh_06_LOD_1'}
  if(!$part){throw "Missing sign submesh: $asset"}
  return $part.Primitives[0].GetVertexAccessor('POSITION').AsVector3Array()
}
function Add-MeasuredDisplay([string]$name,[string]$item,[long]$id,$points,[System.Numerics.Vector3]$outward,[System.Numerics.Vector3]$right) {
  $p=@($points | ForEach-Object {[System.Numerics.Vector3]::new($_.X,-$_.Z,$_.Y)})
  if($p.Count -lt 3){throw "No surface for $name"}
  # Largest baseline and third point give a stable geometric plane, independent
  # of smoothed/quantized vertex normals and of glyph topology.
  $distance=0.0;$a=$p[0];$b=$p[1]
  for($i=0;$i -lt $p.Count;$i++){for($j=$i+1;$j -lt $p.Count;$j++){
    $d=[System.Numerics.Vector3]::DistanceSquared($p[$i],$p[$j])
    if($d -gt $distance){$distance=$d;$a=$p[$i];$b=$p[$j]}
  }}
  $area=0.0;$normal=[System.Numerics.Vector3]::Zero
  foreach($v in $p){$cross=[System.Numerics.Vector3]::Cross(($b-$a),($v-$a));if($cross.LengthSquared() -gt $area){$area=$cross.LengthSquared();$normal=$cross}}
  if($area -lt 0.00000001){throw "Degenerate surface $name"}
  $normal=[System.Numerics.Vector3]::Normalize($normal)
  if([System.Numerics.Vector3]::Dot($normal,$outward) -lt 0){$normal=-$normal}
  $x=[System.Numerics.Vector3]::Normalize(($right-$normal*[System.Numerics.Vector3]::Dot($right,$normal)))
  $z=[System.Numerics.Vector3]::Cross($x,$normal)
  $xs=@($p|ForEach-Object {[System.Numerics.Vector3]::Dot($_,$x)})|Measure-Object -Minimum -Maximum
  $zs=@($p|ForEach-Object {[System.Numerics.Vector3]::Dot($_,$z)})|Measure-Object -Minimum -Maximum
  $ys=@($p|ForEach-Object {[System.Numerics.Vector3]::Dot($_,$normal)})|Measure-Object -Minimum -Maximum
  $residual=$ys.Maximum-$ys.Minimum
  # Decal glyphs include millimetric depth offsets; reject a mixed surface.
  if($residual -gt 0.005){throw "Nonplanar selection $name residual=$residual"}
  # 1.5mm outside the native plane prevents coplanar overlap, not a guessed offset.
  $center=$x*[single](($xs.Minimum+$xs.Maximum)/2)+$z*[single](($zs.Minimum+$zs.Maximum)/2)+$normal*[single]($ys.Maximum+0.0015)
  $matrix=[System.Numerics.Matrix4x4]::new($x.X,$x.Y,$x.Z,0,$normal.X,$normal.Y,$normal.Z,0,$z.X,$z.Y,$z.Z,0,0,0,0,1)
  $q=[System.Numerics.Quaternion]::Normalize([System.Numerics.Quaternion]::CreateFromRotationMatrix($matrix))
  $width=$xs.Maximum-$xs.Minimum;$height=$zs.Maximum-$zs.Minimum
  Write-Host "MEASURE $name center=$center normal=$normal size=$width,$height residual=$residual quaternion=$q"
  Add-DisplayPair $name $item $id $center.X $center.Y $center.Z $q.X $q.Y $q.Z $q.W $width $height
}
$body=Get-SignPoints 'base\vehicles\special\v_mahir_mt28_coach\entities\meshes\v_mahir_mt28_coach__ext01_body_01.mesh'
$inside=Get-SignPoints 'base\vehicles\special\v_mahir_mt28_coach\entities\meshes\v_mahir_mt28_coach__int01_interior_01.mesh'
Add-MeasuredDisplay 'right_route' 'Route' 90170000000030 @($body|Where-Object {$_.X -lt -1.2 -and $_.Y -gt 1.8 -and $_.Z -gt 2.3 -and $_.Z -lt 3.9}) ([System.Numerics.Vector3]::new(-1,0,0)) ([System.Numerics.Vector3]::new(0,1,0))
Add-MeasuredDisplay 'left_route' 'Route' 90170000000040 @($body|Where-Object {$_.X -gt 1.2 -and $_.Y -gt 1.8 -and $_.Z -gt 2.3 -and $_.Z -lt 3.9}) ([System.Numerics.Vector3]::new(1,0,0)) ([System.Numerics.Vector3]::new(0,-1,0))
Add-MeasuredDisplay 'front_route' 'Route' 90170000000020 @($body|Where-Object {$_.Y -gt 1.75 -and $_.Z -lt -4.8 -and $_.Z -gt -5.0}) ([System.Numerics.Vector3]::new(0,1,0)) ([System.Numerics.Vector3]::new(1,0,0))
Add-MeasuredDisplay 'front_line' 'FrontLine' 90170000000010 @($body|Where-Object {$_.X -gt -0.96 -and $_.X -lt -0.57 -and $_.Z -gt -5.40 -and $_.Z -lt -5.37 -and $_.Y -gt 1.70}) ([System.Numerics.Vector3]::new(0,1,0)) ([System.Numerics.Vector3]::new(1,0,0))
Add-MeasuredDisplay 'rear_line' 'RearLine' 90170000000050 @($body|Where-Object {$_.Y -gt 1.75 -and $_.Z -gt 4.8}) ([System.Numerics.Vector3]::new(0,-1,0)) ([System.Numerics.Vector3]::new(-1,0,0))
Add-MeasuredDisplay 'interior_route' 'Route' 90170000000000 @($inside|Where-Object {$_.Y -gt 1.75 -and $_.Z -lt -4.8}) ([System.Numerics.Vector3]::new(0,-1,0)) ([System.Numerics.Vector3]::new(-1,0,0))
