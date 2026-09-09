param([string]$WolvenKitPath='F:\Program Files\GOG Galaxy\Games\my mods\WolvenKit-8.20.0.zip 2201 8.20.0 2026-08-06T08-14Z xNHtNXgDX')
$ErrorActionPreference='Stop'
Get-ChildItem $WolvenKitPath -Filter '*.dll' | ForEach-Object {try {[Reflection.Assembly]::LoadFrom($_.FullName)|Out-Null}catch{}}
$output=Join-Path (Split-Path $PSScriptRoot -Parent) 'tmp\display-prototype\nctc\ui\bus_display.inkwidget'
New-Item -ItemType Directory -Force (Split-Path $output -Parent)|Out-Null
$resource=[WolvenKit.RED4.Types.inkWidgetLibraryResource]::new()
$package=[WolvenKit.RED4.Archive.Buffer.RedPackage]::new()
function Add-DisplayItem([string]$itemName,[string]$rootName) {
  $item=[WolvenKit.RED4.Types.inkWidgetLibraryItem]::new()
  $item.Name=[WolvenKit.RED4.Types.CName]$itemName
  $instance=[WolvenKit.RED4.Types.inkWidgetLibraryItemInstance]::new()
  $canvas=[WolvenKit.RED4.Types.inkCanvasWidget]::new()
  $canvas.Name=[WolvenKit.RED4.Types.CName]$rootName
  $canvas.Size.X=[WolvenKit.RED4.Types.CFloat][single]1024
  $canvas.Size.Y=[WolvenKit.RED4.Types.CFloat][single]128
  if($itemName -eq 'Route'){$canvas.Size.Y=[WolvenKit.RED4.Types.CFloat][single]116}
  if($itemName -eq 'RearLine'){$canvas.Size.X=[WolvenKit.RED4.Types.CFloat][single]320;$canvas.Size.Y=[WolvenKit.RED4.Types.CFloat][single]260}
  if($itemName -eq 'FrontLine'){$canvas.Size.X=[WolvenKit.RED4.Types.CFloat][single]320;$canvas.Size.Y=[WolvenKit.RED4.Types.CFloat][single]240}
  if($itemName -eq 'Probe'){
    # Match the 2x1 metre probe before the world-widget target is created.
    $canvas.Size.Y=[WolvenKit.RED4.Types.CFloat][single]512
  }
  $canvas.Visible=[WolvenKit.RED4.Types.CBool]$true
  $canvas.Opacity=[WolvenKit.RED4.Types.CFloat][single]1
  $canvas.Children=[WolvenKit.RED4.Types.CHandle[WolvenKit.RED4.Types.inkMultiChildren]]::new([WolvenKit.RED4.Types.inkMultiChildren]::new())
  # Visible without any script controller: isolates rendering from initialization.
  $probe=[WolvenKit.RED4.Types.inkTextWidget]::new()
  $probe.Name=[WolvenKit.RED4.Types.CName]'NCTCDisplayProbe'
  $probe.Text=[WolvenKit.RED4.Types.CString]'NCTC DISPLAY TEST'
  $probe.FontFamily=[WolvenKit.RED4.Types.CResourceAsyncReference[WolvenKit.RED4.Types.inkFontFamilyResource]]::new('base\gameplay\gui\fonts\raj\raj.inkfontfamily')
  $probe.FontStyle=[WolvenKit.RED4.Types.CName]'Semi-Bold'
  $probe.FontSize=[WolvenKit.RED4.Types.CUInt32][uint32]64
  $probe.Size.X=[WolvenKit.RED4.Types.CFloat][single]1024
  $probe.Size.Y=[WolvenKit.RED4.Types.CFloat][single]128
  $probe.TintColor.Red=[WolvenKit.RED4.Types.CFloat][single]1
  $probe.TintColor.Green=[WolvenKit.RED4.Types.CFloat][single]1
  $probe.TintColor.Blue=[WolvenKit.RED4.Types.CFloat][single]1
  $probe.TintColor.Alpha=[WolvenKit.RED4.Types.CFloat][single]1
  $canvas.Children.GetValue().Children.Add([WolvenKit.RED4.Types.CHandle[WolvenKit.RED4.Types.inkWidget]]::new($probe))
  $instance.RootWidget=[WolvenKit.RED4.Types.CHandle[WolvenKit.RED4.Types.inkWidget]]::new($canvas)
  $controller=[WolvenKit.RED4.Types.DynamicWidgetController]::new()
  $controller.ClassName=[WolvenKit.RED4.Types.CName]'NCTC.NCTCBusDisplayController'
  $instance.GameController=[WolvenKit.RED4.Types.CHandle[WolvenKit.RED4.Types.inkIWidgetController]]::new($controller)
  $itemPackage=[WolvenKit.RED4.Archive.Buffer.RedPackage]::new()
  $itemPackage.Chunks.Add($instance)
  $item.PackageData=[WolvenKit.RED4.Types.DataBuffer]::new()
  $item.PackageData.Buffer.Data=$itemPackage
  $resource.LibraryItems.Add($item)
}
Add-DisplayItem 'Route' 'NCTCBusRouteDisplay'
Add-DisplayItem 'Line' 'NCTCBusLineDisplay'
Add-DisplayItem 'Probe' 'NCTCBusProbeDisplay'
Add-DisplayItem 'FrontLine' 'NCTCBusLineDisplay'
Add-DisplayItem 'RearLine' 'NCTCBusRearLineDisplay'
$file=[WolvenKit.RED4.Archive.CR2W.CR2WFile]::new()
$file.RootChunk=$resource
$stream=[IO.File]::Create($output)
try {
  $writer=[WolvenKit.RED4.Archive.IO.CR2WWriter]::new($stream)
  $writer.WriteFile($file)
} finally {$stream.Dispose()}
$stream=[IO.File]::OpenRead($output)
try {
  $reader=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($stream)
  $readback=$null
  $result=$reader.ReadFile([ref]$readback,$true)
  if($result.ToString() -ne 'NoError' -or $readback.RootChunk.LibraryItems.Count -ne 5){throw 'Widget round-trip validation failed'}
  foreach($libraryItem in $readback.RootChunk.LibraryItems){
    $restored=$libraryItem.PackageData.Data.RootChunk
    if($restored.GameController.GetValue().ClassName.ToString() -ne 'NCTC.NCTCBusDisplayController'){throw 'Widget controller lost during serialization'}
  }
  Write-Output "Widget verified: $output"
} finally {$stream.Dispose()}
