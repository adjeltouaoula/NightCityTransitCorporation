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

// H2 departure only. Points 1-9 preserve the user-validated r376f bay exit.
// Points 10-16 continue through surveyed passage-3 and roughly 20 m down its
// outgoing lane so native traffic reacquires from an unambiguous lane state.
var spline = new Spline { Looped = false, Reversed = false, HasDirection = true };
spline.Points.Add(Point(-0.45f, -17.20f, 0.0f, 1));
spline.Points.Add(Point(-0.65f, -23.00f, 0.0f, 2));
spline.Points.Add(Point(-0.90f, -29.00f, 0.0f, 3));
spline.Points.Add(Point(-0.80f, -33.00f, 0.0f, 4));
spline.Points.Add(Point( 1.20f, -37.00f, 0.0f, 5));
spline.Points.Add(Point( 4.10f, -41.00f, 0.0f, 6));
spline.Points.Add(Point( 6.60f, -45.50f, 0.0f, 7));
spline.Points.Add(Point( 7.40f, -50.00f, 0.0f, 8));
spline.Points.Add(Point( 7.40f, -62.00f, 0.0f, 9));
// passage-3 world=(-2103.407,-1090.684), yaw=-92.59 deg.
// With the spline node origin (-2161.015,-1012.713), passage local is
// (57.608,-77.971). The last point is ~20 m farther along yaw -92.59.
spline.Points.Add(Point( 7.60f, -67.00f, 0.0f, 10));
spline.Points.Add(Point(10.00f, -71.50f, 0.0f, 11));
spline.Points.Add(Point(16.00f, -75.00f, 0.0f, 12));
spline.Points.Add(Point(26.00f, -77.00f, 0.0f, 13));
spline.Points.Add(Point(40.00f, -77.50f, 0.0f, 14));
spline.Points.Add(Point(57.608f, -77.971f, 0.0f, 15));
spline.Points.Add(Point(77.588f, -78.875f, 0.0f, 16));

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
    Bounds = Box4(-2170f, -1110f, 5f, -2075f, -1025f, 12f),
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
    StreamingBox = Box4(-2220f, -1150f, 0f, -2050f, -1000f, 30f),
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
if (parsedSplineNode.SplineData.Chunk?.Points.Count != 16)
    throw new Exception("wrong departure spline point count");
if (parsedSector.NodeRefs.Count != 1)
    throw new Exception("missing departure node ref");
Console.WriteLine($"R377A_WORLD_OK nodeRef={parsedSector.NodeRefs[0]} points={parsedSplineNode.SplineData.Chunk.Points.Count}");
