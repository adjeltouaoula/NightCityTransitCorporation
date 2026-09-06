param(
  [string]$WolvenKitPath = 'F:\Program Files\GOG Galaxy\Games\my mods\WolvenKit-8.20.0.zip 2201 8.20.0 2026-08-06T08-14Z xNHtNXgDX',
  [string]$GamePath = 'F:\Program Files\GOG Galaxy\Games\Cyberpunk 2077'
)
$ErrorActionPreference = 'Stop'
Get-ChildItem -LiteralPath $WolvenKitPath -Filter '*.dll' | ForEach-Object {
  try { [Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch { }
}
$hash = [WolvenKit.Common.Services.HashService]::new()
$hash.Load()
$reader = [WolvenKit.RED4.Archive.IO.ArchiveReader]::new()
$archive = $null
$result = $reader.ReadArchive((Join-Path $GamePath 'archive\pc\content\basegame_4_appearance.archive'), $hash, [ref]$archive)
if ($result.ToString() -ne 'NoError') { throw "Archive read failed: $result" }
$asset = 'base\vehicles\special\v_mahir_mt28_coach\entities\meshes\v_mahir_mt28_coach__int01_interior_01.mesh'
$outputPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'tmp\mahir-display'
New-Item -ItemType Directory -Force $outputPath | Out-Null
$key = [WolvenKit.Common.FNV1A.FNV1A64HashAlgorithm]::HashString($asset)
$stream = [IO.MemoryStream]::new()
try {
  $archive.ExtractFile($archive.Files[$key], $stream)
  $stream.Position = 0
  $cr2wReader = [WolvenKit.RED4.Archive.IO.CR2WReader]::new($stream)
  $file = $null
  $result = $cr2wReader.ReadFile([ref]$file, $true)
  if ($result.ToString() -ne 'NoError') { throw "Mesh read failed: $result" }
  foreach ($entry in $file.RootChunk.MaterialEntries) {
    if ($entry.Name.ToString() -notmatch 'busnumber') { continue }
    $index = [int]$entry.Index.ToString()
    $material = $file.RootChunk.LocalMaterialBuffer.Materials[$index]
    Write-Output "Material: $($entry.Name) (index $index)"
    Write-Output "Base: $($material.BaseMaterial.DepotPath)"
    foreach ($value in $material.Values) { Write-Output "  $($value.Key): $($value.Value)" }
  }
  $model = [WolvenKit.Modkit.RED4.Tools.MeshTools]::GetModel($file, $false, $false, [UInt64]::MaxValue, $false, $false)
  $appearance = $file.RootChunk.Appearances[0].GetValue()
  $submeshIndex = 0
  foreach ($mesh in $model.LogicalMeshes) {
    foreach ($primitive in $mesh.Primitives) {
      $materialName = $appearance.ChunkMaterials[$submeshIndex].ToString()
      if ($materialName -match 'busnumber') {
        Write-Output "Submesh: $($mesh.Name), material: $materialName"
        $positions = $primitive.GetVertexAccessor('POSITION').AsVector3Array()
        $uvs = $primitive.GetVertexAccessor('TEXCOORD_0').AsVector2Array()
        Write-Output "  vertices=$($positions.Count)"
      }
      $submeshIndex++
    }
  }
  $model.SaveGLB((Join-Path $outputPath 'interior-inspection.glb'))
} finally { $stream.Dispose() }

$texture = 'base\vehicles\common\textures\common_font_municipal.xbm'
$textureKey = [WolvenKit.Common.FNV1A.FNV1A64HashAlgorithm]::HashString($texture)
$textureArchive = $archive
if (!$textureArchive.Files.ContainsKey($textureKey)) {
  foreach ($archiveFile in Get-ChildItem (Join-Path $GamePath 'archive\pc\content') -Filter '*.archive') {
    $candidate = $null
    $null = $reader.ReadArchive($archiveFile.FullName, $hash, [ref]$candidate)
    if ($candidate.Files.ContainsKey($textureKey)) { $textureArchive = $candidate; break }
  }
}
if (!$textureArchive.Files.ContainsKey($textureKey)) { throw 'Municipal font texture not found' }
$textureStream = [IO.MemoryStream]::new()
try {
  $textureArchive.ExtractFile($textureArchive.Files[$textureKey], $textureStream)
  $textureStream.Position = 0
  $parser = [WolvenKit.RED4.CR2W.Red4ParserService]::new($hash, $null, $null)
  $modTools = [WolvenKit.Modkit.RED4.ModTools]::new($null, $null, $hash, $parser, $null, $null)
  $exportArgs = [WolvenKit.Common.Model.Arguments.GlobalExportArgs]::new()
  $null = $exportArgs.Register([WolvenKit.Common.Model.Arguments.ExportArgs[]]@([WolvenKit.Common.Model.Arguments.XbmExportArgs]::new()))
  $ok = $modTools.UncookXBM($textureStream, [IO.FileInfo]::new((Join-Path $outputPath 'common_font_municipal.xbm')), $exportArgs)
  Write-Output "Texture export: $ok"
} finally { $textureStream.Dispose() }
