# Shared geometry classification for removal and placement (glTF coordinates).
function Get-RouteRegion($v,[bool]$interior) {
 if($v.Y -le 1.75){return ''}
 if($interior){if($v.Z -lt -4.8){return 'interior_route'};return ''}
 if($v.Z -lt -4.8 -and $v.Z -gt -5.0){return 'front_route'}
 if($v.Z -gt 2.3 -and $v.Z -lt 3.9){
  if($v.X -lt -1.2){return 'right_route'}
  if($v.X -gt 1.2){return 'left_route'}
 }
 return ''
}
function Get-RouteHorizontal($v,[string]$region) {
 switch($region){
  'right_route' {return -$v.Z}
  'left_route' {return $v.Z}
  'interior_route' {return -$v.X}
  'front_route' {return $v.X}
 }
 throw "Not a route panel: $region"
}
function Get-RouteSplits($positions,[bool]$interior) {
 $groups=@{}
 foreach($v in $positions){
  $r=Get-RouteRegion $v $interior
  if(!$r){continue}
  if(!$groups.ContainsKey($r)){$groups[$r]=[Collections.Generic.List[double]]::new()}
  $groups[$r].Add((Get-RouteHorizontal $v $r))
 }
 $result=@{}
 foreach($r in $groups.Keys){
  $values=@($groups[$r]|Sort-Object -Unique);$min=$values[0];$max=$values[-1];$width=$max-$min
  $gap=0.0;$split=0.0
  for($i=1;$i -lt $values.Count;$i++){
   $mid=($values[$i]+$values[$i-1])/2;$u=($mid-$min)/$width
   if($u -lt 0.20 -or $u -gt 0.65){continue}
   $d=$values[$i]-$values[$i-1]
   if($d -gt $gap){$gap=$d;$split=$mid}
  }
  if($gap -lt $width*0.012){throw "Cannot isolate native NEXT/STOP header: $r"}
  $result[$r]=@{Split=$split;Min=$min;Max=$max;Fraction=($split-$min)/$width}
  Write-Host "HEADER $r boundary=$split fraction=$($result[$r].Fraction) gap=$gap"
 }
 return $result
}
