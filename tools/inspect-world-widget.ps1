param([string]$Asset='base\gameplay\devices\fast_travel\appearences\data_term.app')
$ErrorActionPreference='Stop'
$wk='F:\Program Files\GOG Galaxy\Games\my mods\WolvenKit-8.20.0.zip 2201 8.20.0 2026-08-06T08-14Z xNHtNXgDX'
Get-ChildItem $wk -Filter '*.dll' | ForEach-Object {try {[Reflection.Assembly]::LoadFrom($_.FullName)|Out-Null}catch{}}
$hash=[WolvenKit.Common.Services.HashService]::new()
$hash.Load()
$arReader=[WolvenKit.RED4.Archive.IO.ArchiveReader]::new()
$id=[WolvenKit.Common.FNV1A.FNV1A64HashAlgorithm]::HashString($Asset)
foreach($path in Get-ChildItem 'F:\Program Files\GOG Galaxy\Games\Cyberpunk 2077\archive\pc\content' -Filter '*.archive') {
  $archive=$null
  $null=$arReader.ReadArchive($path.FullName,$hash,[ref]$archive)
  if(!$archive.Files.ContainsKey($id)){continue}
  $stream=[IO.MemoryStream]::new()
  try {
    $archive.ExtractFile($archive.Files[$id],$stream)
    $stream.Position=0
    $reader=[WolvenKit.RED4.Archive.IO.CR2WReader]::new($stream)
    $file=$null
    $null=$reader.ReadFile([ref]$file,$true)
    $file.RootChunk|Format-List *
    Write-Output "Library count=$($file.RootChunk.LibraryItems.Count)"
    foreach($item in $file.RootChunk.LibraryItems){$item|Format-List *;$item.Package.Data|Format-List *;$item.PackageData.Data|Format-List *}
    $file.RootChunk.GetPropertyNames() | ForEach-Object {Write-Output "property $_"}
    $file.RootChunk.GetDynamicProperties() | Format-List *
    Write-Output "Embedded=$($file.EmbeddedFiles.Count)"
    $file.RootChunk.GetType().GetMethods() | Where-Object Name -match 'Buffer' | ForEach-Object ToString
    $file | Format-List *
    foreach($handle in $file.RootChunk.Appearances) {
      $appearance=$handle.GetValue()
      Write-Output "Appearance $($appearance.Name)"
      foreach($chunk in $appearance.CompiledData.Data.Chunks) {
        Write-Output "$($chunk.GetType().Name) $($chunk.Name)"
        if($chunk.GetType().Name -match 'Widget'){$chunk|Format-List *}
      }
      break
    }
  } finally {$stream.Dispose()}
  break
}
