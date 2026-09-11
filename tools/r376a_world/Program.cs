using System.Text;
using WolvenKit.RED4.Archive.Buffer;
using WolvenKit.RED4.Archive.CR2W;
using WolvenKit.RED4.Archive.IO;
using WolvenKit.RED4.Types;
using static WolvenKit.RED4.Types.Enums;

static Vector3 V3(float x,float y,float z)=>new(){X=x,Y=y,Z=z};
static Vector4 V4(float x,float y,float z,float w=0)=>new(){X=x,Y=y,Z=z,W=w};
static Box B(float ax,float ay,float az,float bx,float by,float bz)=>new(){Min=V4(ax,ay,az),Max=V4(bx,by,bz)};
static SplinePoint P(float x,float y,float z,uint id)=>new(){Position=V3(x,y,z),Id=id,AutomaticTangents=true,ContinuousTangents=true};
static void Write(string path, RedBaseClass root){var f=new CR2WFile{RootChunk=root};using(var fs=File.Create(path))using(var w=new CR2WWriter(fs))w.WriteFile(f);using var input=File.OpenRead(path);using var r=new CR2WReader(input,Encoding.UTF8,false);if(r.ReadFile(out var parsed)!=EFileReadErrorCodes.NoError||parsed is null)throw new Exception("CR2W roundtrip failed "+path);}

const string nodeRefText="$/nctc/bays/h2/arrival_spline";
const string sectorDepot="nctc\\bays\\h2\\sectors\\h2_arrival.streamingsector";
NodeRef nodeRef=nodeRefText;
var spline=new Spline{Looped=false,Reversed=false,HasDirection=true};
// H2 P1=(-2161.015,-1012.713), P2=(-2162.260,-1043.903).
// The first two points lie on the observed live road centreline (+4.2 m lateral).
// The remaining points form one monotonic, continuous merge onto the bay axis.
spline.Points.Add(P( 5.074125f, 21.814978f,0,1));
spline.Points.Add(P( 4.595507f,  9.824526f,0,2));
spline.Points.Add(P( 4.196658f, -0.167516f,0,3));
spline.Points.Add(P( 2.298586f, -5.095734f,0,4));
spline.Points.Add(P( 0.400515f,-10.023951f,0,5));
spline.Points.Add(P(-0.598273f,-14.988064f,0,6));
spline.Points.Add(P(-0.797698f,-19.984086f,0,7));

var node=new worldSplineNode{SplineData=new CHandle<Spline>(spline)};
var sector=new worldStreamingSector{Version=62,Level=0,Category=worldStreamingSectorCategory.Exterior};
sector.VariantIndices.Add(0);
sector.Nodes.Add(new CHandle<worldNode>(node));
sector.NodeRefs.Add(nodeRef);
var nd=new worldNodeDataBuffer();
nd.Add(new worldNodeData{
    Id=1,NodeIndex=0,
    Position=V4(-2161.015f,-1012.713f,7.851f),
    Orientation=new Quaternion{R=1},
    Scale=V3(1,1,1),
    Pivot=V3(-2161.015f,-1012.713f,7.851f),
    Bounds=B(-2170,-1045,5,-2150,-985,12),
    QuestPrefabRefHash=nodeRef,
    MaxStreamingDistance=250,UkFloat1=300,Uk10=1024,Uk11=512
});
sector.NodeData=new DataBuffer();
sector.NodeData.Data=nd;
sector.NodeData.Buffer.Parent=sector;
sector.NodeData.Buffer.ParentTypes.Add("worldStreamingSector.transforms");

var block=new worldStreamingBlock();
block.Descriptors.Add(new worldStreamingSectorDescriptor{
    Data=new CResourceAsyncReference<worldStreamingSector>((ResourcePath)sectorDepot),
    StreamingBox=B(-2220,-1100,0,-2100,-950,30),
    NumNodeRanges=1,Level=0,Category=worldStreamingSectorCategory.Exterior
});

var root=Environment.GetEnvironmentVariable("RAW_ROOT") ?? throw new Exception("RAW_ROOT missing");
var sp=Path.Combine(root,"nctc","bays","h2","sectors","h2_arrival.streamingsector");
var bp=Path.Combine(root,"nctc","bays","h2","all.streamingblock");
Directory.CreateDirectory(Path.GetDirectoryName(sp)!);
Write(sp,sector);
Write(bp,block);

using var inp=File.OpenRead(sp);
using var rr=new CR2WReader(inp,Encoding.UTF8,false);
if(rr.ReadFile(out var parsed)!=EFileReadErrorCodes.NoError)throw new Exception("verify failed");
var ps=(worldStreamingSector)parsed!.RootChunk;
var sn=(worldSplineNode)ps.Nodes[0].Chunk!;
if(sn.SplineData.Chunk?.Points.Count!=7)throw new Exception("wrong points");
if(ps.NodeRefs.Count!=1)throw new Exception("nodeRef missing");
Console.WriteLine($"R376A_WORLD_OK ref={ps.NodeRefs[0]} points={sn.SplineData.Chunk.Points.Count}");
