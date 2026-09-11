using System.Text;
using WolvenKit.RED4.Archive.Buffer;
using WolvenKit.RED4.Archive.CR2W;
using WolvenKit.RED4.Archive.IO;
using WolvenKit.RED4.Types;
using static WolvenKit.RED4.Types.Enums;

static Vector3 V3(float x, float y, float z) => new() { X = x, Y = y, Z = z };
static Vector4 V4(float x, float y, float z, float w = 0f) => new() { X = x, Y = y, Z = z, W = w };
static Box Box4(float minX, float minY, float minZ, float maxX, float maxY, float maxZ) => new()
{
    Min = V4(minX, minY, minZ), Max = V4(maxX, maxY, maxZ)
};
static SplinePoint Point(float x, float y, float z, uint id) => new()
{
    Position = V3(x, y, z), Id = id, AutomaticTangents = true, ContinuousTangents = true
};
static void WriteAndRoundTrip(string path, RedBaseClass root, Type expectedType)
{
    var file = new CR2WFile { RootChunk = root };
    using (var fs = File.Create(path))
    using (var writer = new CR2WWriter(fs)) writer.WriteFile(file);
    using var input = File.OpenRead(path);
    using var reader = new CR2WReader(input, Encoding.UTF8, false);
    var result = reader.ReadFile(out var parsed);
    if (result != EFileReadErrorCodes.NoError || parsed is null)
        throw new Exception($"readback failed {path}: {result}");
    if (parsed.RootChunk.GetType() != expectedType)
        throw new Exception($"unexpected root {parsed.RootChunk.GetType()} for {path}");
}

const string nodeRefText = "$/nctc/bays/h2/departure_spline";
const string sectorDepotPath = "nctc\\bays\\h2\\departure\\sectors\\h2_departure.streamingsector";
NodeRef nodeRef = nodeRefText;

// H2 departure only. Local coordinates use the exact same P1 origin as the
// validated r376a arrival. Hold the bus on the bay axis until P2, merge only
// after the bay end, then finish with a straight road-aligned tail.
var spline = new Spline { Looped = false, Reversed = false, HasDirection = true };
spline.Points.Add(Point(-0.45f, -17.20f, 0.0f, 1));
spline.Points.Add(Point(-0.65f, -23.00f, 0.0f, 2));
spline.Points.Add(Point(-0.90f, -29.00f, 0.0f, 3));
spline.Points.Add(Point(-0.80f, -33.00f, 0.0f, 4));
spline.Points.Add(Point( 0.20f, -37.00f, 0.0f, 5));
spline.Points.Add(Point( 2.00f, -41.00f, 0.0f, 6));
spline.Points.Add(Point( 3.50f, -45.50f, 0.0f, 7));
spline.Points.Add(Point( 4.10f, -50.00f, 0.0f, 8));
spline.Points.Add(Point( 4.15f, -62.00f, 0.0f, 9));

var splineNode = new worldSplineNode { SplineData = new CHandle<Spline>(spline) };
var sector = new worldStreamingSector
{
    Version = 62,
    Level = 0,
    Category = worldStreamingSectorCategory.Exterior
};
sector.VariantIndices.Add(0);
sector.Nodes.Add(new CHandle<worldNode>(splineNode));
sector.NodeRefs.Add(nodeRef);

var nodeData = new worldNodeDataBuffer();
nodeData.Add(new worldNodeData
{
    Id = 1,
    NodeIndex = 0,
    Position = V4(-2161.015f, -1012.713f, 7.851f),
    Orientation = new Quaternion { R = 1.0f },
    Scale = V3(1.0f, 1.0f, 1.0f),
    Pivot = V3(-2161.015f, -1012.713f, 7.851f),
    Bounds = Box4(-2170f, -1080f, 5f, -2150f, -1025f, 12f),
    QuestPrefabRefHash = nodeRef,
    MaxStreamingDistance = 250.0f,
    UkFloat1 = 300.0f,
    Uk10 = 1024,
    Uk11 = 512
});
sector.NodeData = new DataBuffer();
sector.NodeData.Data = nodeData;
sector.NodeData.Buffer.Parent = sector;
sector.NodeData.Buffer.ParentTypes.Add("worldStreamingSector.transforms");

var block = new worldStreamingBlock();
block.Descriptors.Add(new worldStreamingSectorDescriptor
{
    Data = new CResourceAsyncReference<worldStreamingSector>((ResourcePath)sectorDepotPath),
    StreamingBox = Box4(-2220f, -1150f, 0f, -2100f, -1000f, 30f),
    NumNodeRanges = 1,
    Level = 0,
    Category = worldStreamingSectorCategory.Exterior
});

var root = Environment.GetEnvironmentVariable("RAW_ROOT") ?? throw new Exception("RAW_ROOT missing");
var sectorPath = Path.Combine(root, "nctc", "bays", "h2", "departure", "sectors", "h2_departure.streamingsector");
var blockPath = Path.Combine(root, "nctc", "bays", "h2", "departure", "all.streamingblock");
Directory.CreateDirectory(Path.GetDirectoryName(sectorPath)!);
WriteAndRoundTrip(sectorPath, sector, typeof(worldStreamingSector));
WriteAndRoundTrip(blockPath, block, typeof(worldStreamingBlock));

using var verify = File.OpenRead(sectorPath);
using var rr = new CR2WReader(verify, Encoding.UTF8, false);
if (rr.ReadFile(out var parsedSectorFile) != EFileReadErrorCodes.NoError)
    throw new Exception("sector verify failed");
var parsedSector = (worldStreamingSector)parsedSectorFile!.RootChunk;
var parsedSplineNode = parsedSector.Nodes[0].Chunk as worldSplineNode ?? throw new Exception("not spline node");
if (parsedSplineNode.SplineData.Chunk?.Points.Count != 9)
    throw new Exception("wrong departure spline point count");
if (parsedSector.NodeRefs.Count != 1)
    throw new Exception("missing departure node ref");
Console.WriteLine($"R376B_WORLD_OK nodeRef={parsedSector.NodeRefs[0]} points={parsedSplineNode.SplineData.Chunk.Points.Count}");
