from pathlib import Path
import json, math

ROOT=Path('.')
SRC=ROOT/'source/redscript/NCTC/NCTCTransitSystem.reds'
text=SRC.read_text(encoding='utf-8')

if 'nctc_dev_build_revision\", 37502' not in text:
    raise SystemExit('expected r375b runtime marker not found')
text=text.replace('nctc_dev_build_revision\", 37502', 'nctc_dev_build_revision\", 37601', 1)

marker='\n\n// NCTC owns the native autonomous command lifecycle.'
if marker not in text:
    raise SystemExit('controller marker missing')
spline_class=r'''

// r376a: one native vehicle-spline command owns the complete H2 bay arc.
// Unlike DriveToPoint, intermediate control points are geometry, not destinations.
public class NCTCDeferredSplineDriveCommand extends DelayCallback {
  private let bus: wref<VehicleObject>;
  private let controller: wref<NCTCServiceBusController>;
  private let splineRef: NodeRef;
  private let startSpeed: Float;
  private let commandGeneration: Int32;

  public func Configure(bus: ref<VehicleObject>, controller: ref<NCTCServiceBusController>, splineRef: NodeRef, startSpeed: Float, commandGeneration: Int32) -> ref<NCTCDeferredSplineDriveCommand> {
    this.bus = bus;
    this.controller = controller;
    this.splineRef = splineRef;
    this.startSpeed = startSpeed;
    this.commandGeneration = commandGeneration;
    return this;
  }

  public func Call() -> Void {
    let command: ref<AIVehicleOnSplineCommand>;
    if !IsDefined(this.bus) || !this.bus.IsAttached() || !IsDefined(this.bus.GetAIComponent()) { return; };
    if IsDefined(this.controller) && !this.controller.IsDriveGenerationCurrent(this.commandGeneration) {
      this.controller.ReportStaleDriveCallback(this.commandGeneration);
      return;
    };
    command = new AIVehicleOnSplineCommand();
    command.splineRef = this.splineRef;
    command.secureTimeOut = 120.00;
    command.driveBackwards = false;
    command.reverseSpline = false;
    command.startFromClosest = true;
    command.forcedStartSpeed = MaxF(this.startSpeed, 0.00);
    command.stopAtPathEnd = true;
    command.needDriver = false;
    command.useKinematic = false;
    this.bus.GetAIComponent().SendCommand(command);
    if IsDefined(this.controller) { this.controller.SetActiveSplineCommand(command, this.commandGeneration); };
  }
}
'''
text=text.replace(marker, spline_class+marker, 1)

old='''  private let activeRouteCommand: ref<AIVehicleDriveToPointCommand>;\n  // Diagnostic-only: retain the command that was active immediately before a\n'''
new='''  private let activeRouteCommand: ref<AIVehicleDriveToPointCommand>;\n  // r376a H2 prototype: native curve follower, isolated from ordinary route commands.\n  private let activeSplineCommand: ref<AIVehicleOnSplineCommand>;\n  // Diagnostic-only: retain the command that was active immediately before a\n'''
if old not in text: raise SystemExit('activeRouteCommand field anchor missing')
text=text.replace(old,new,1)

old=r'''  // r373a: keep normal traffic navigation for the route, then hand the last
  // metres to the autonomous point driver so the Mahir may leave the traffic
  // lane and enter a surveyed bus bay / berth.
  public func DriveToBerthDirect(target: Vector4, startSpeed: Float, maxSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredBerthDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let generation: Int32;
    if !this.IsReady() { return false; };
    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.activeRouteCommand = null;
    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    callback = new NCTCDeferredBerthDriveCommand();
    callback.Configure(this.bus, this, target, MaxF(startSpeed, 0.00), maxSpeed, generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }
'''
new=r'''  private func IsH2SplinePrototypeTarget(target: Vector4) -> Bool {
    return target.X > -2200.00 && target.X < -2100.00 && target.Y > -1100.00 && target.Y < -950.00;
  }

  private func IsH2ServicePoint(target: Vector4) -> Bool {
    let service: Vector4 = new Vector4(-2161.824, -1032.987, 7.848, 1.00);
    return Vector4.Distance(target, service) <= 6.00;
  }

  private func DriveH2SplinePrototype(target: Vector4, startSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredSplineDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let generation: Int32;
    let splineRef: NodeRef;
    let isExit: Bool;
    if !this.IsReady() { return false; };

    if this.IsH2ServicePoint(target) && IsDefined(this.activeSplineCommand)
      && !Equals(this.activeSplineCommand.state, AICommandState.Failure)
      && !Equals(this.activeSplineCommand.state, AICommandState.Cancelled)
      && !Equals(this.activeSplineCommand.state, AICommandState.Interrupted) {
      return true;
    };

    isExit = target.Y < -1045.00 && target.X > -2160.50;
    splineRef = isExit
      ? CreateNodeRef("$/03_night_city/#nctc/#h2_bay_exit")
      : CreateNodeRef("$/03_night_city/#nctc/#h2_bay_entry");

    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleOnSplineCommand", false, true);
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;

    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);

    callback = new NCTCDeferredSplineDriveCommand();
    callback.Configure(this.bus, this, splineRef, MaxF(startSpeed, 1.00), generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_h2_spline_phase", isExit ? 2 : 1);
    GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_h2_spline_id", GameInstance.GetQuestsSystem(this.bus.GetGame()).GetFact(n"nctc_dev_h2_spline_id") + 1);
    return true;
  }

  // r376a: H2 uses a native continuous spline. Other bays keep r375b only as
  // a compatibility fallback and are not part of this prototype validation.
  public func DriveToBerthDirect(target: Vector4, startSpeed: Float, maxSpeed: Float) -> Bool {
    let callback: ref<NCTCDeferredBerthDriveCommand>;
    let noDriver: ref<AIEvent>;
    let driverReady: ref<AIEvent>;
    let generation: Int32;
    if !this.IsReady() { return false; };
    if this.IsH2SplinePrototypeTarget(target) { return this.DriveH2SplinePrototype(target, startSpeed); };
    generation = this.NextDriveGeneration();
    this.previousRouteCommand = this.activeRouteCommand;
    this.bus.GetAIComponent().CancelOrInterruptCommand(n"AIVehicleDriveToPointCommand", false, true);
    this.activeRouteCommand = null;
    this.activeSplineCommand = null;
    noDriver = new AIEvent();
    driverReady = new AIEvent();
    noDriver.name = n"NoDriver";
    driverReady.name = n"DriverReady";
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEventNextFrame(this.bus, noDriver);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayEvent(this.bus, driverReady, 0.030);
    callback = new NCTCDeferredBerthDriveCommand();
    callback.Configure(this.bus, this, target, MaxF(startSpeed, 0.00), maxSpeed, generation);
    GameInstance.GetDelaySystem(this.bus.GetGame()).DelayCallback(callback, 0.060, false);
    return true;
  }
'''
if old not in text: raise SystemExit('DriveToBerthDirect block missing')
text=text.replace(old,new,1)

old=r'''  public func SetActiveRouteCommand(command: ref<AIVehicleDriveToPointCommand>, generation: Int32) -> Void {
    if !this.IsDriveGenerationCurrent(generation) { return; };
    this.activeRouteCommand = command;
  }

  public func IsRouteCommandSuccessful() -> Bool {
    return IsDefined(this.activeRouteCommand) && Equals(this.activeRouteCommand.state, AICommandState.Success);
  }
'''
new=r'''  public func SetActiveRouteCommand(command: ref<AIVehicleDriveToPointCommand>, generation: Int32) -> Void {
    if !this.IsDriveGenerationCurrent(generation) { return; };
    this.activeSplineCommand = null;
    this.activeRouteCommand = command;
  }

  public func SetActiveSplineCommand(command: ref<AIVehicleOnSplineCommand>, generation: Int32) -> Void {
    if !this.IsDriveGenerationCurrent(generation) { return; };
    this.activeRouteCommand = null;
    this.activeSplineCommand = command;
  }

  public func IsRouteCommandSuccessful() -> Bool {
    if IsDefined(this.activeSplineCommand) { return Equals(this.activeSplineCommand.state, AICommandState.Success); };
    return IsDefined(this.activeRouteCommand) && Equals(this.activeRouteCommand.state, AICommandState.Success);
  }
'''
if old not in text: raise SystemExit('SetActiveRouteCommand block missing')
text=text.replace(old,new,1)

old=r'''  public func GetRouteCommandStatusCode() -> Int32 {
    if !IsDefined(this.activeRouteCommand) { return 0; };
    if Equals(this.activeRouteCommand.state, AICommandState.Success) { return 2; };
    if Equals(this.activeRouteCommand.state, AICommandState.Failure)
      || Equals(this.activeRouteCommand.state, AICommandState.Cancelled)
      || Equals(this.activeRouteCommand.state, AICommandState.Interrupted) { return 3; };
    return 1;
  }
'''
new=r'''  public func GetRouteCommandStatusCode() -> Int32 {
    if IsDefined(this.activeSplineCommand) {
      if Equals(this.activeSplineCommand.state, AICommandState.Success) { return 2; };
      if Equals(this.activeSplineCommand.state, AICommandState.Failure)
        || Equals(this.activeSplineCommand.state, AICommandState.Cancelled)
        || Equals(this.activeSplineCommand.state, AICommandState.Interrupted) { return 3; };
      return 1;
    };
    if !IsDefined(this.activeRouteCommand) { return 0; };
    if Equals(this.activeRouteCommand.state, AICommandState.Success) { return 2; };
    if Equals(this.activeRouteCommand.state, AICommandState.Failure)
      || Equals(this.activeRouteCommand.state, AICommandState.Cancelled)
      || Equals(this.activeRouteCommand.state, AICommandState.Interrupted) { return 3; };
    return 1;
  }
'''
if old not in text: raise SystemExit('GetRouteCommandStatusCode block missing')
text=text.replace(old,new,1)

old=r'''  public func IsRouteCommandFailed() -> Bool {
    if !IsDefined(this.activeRouteCommand) { return false; };
    return Equals(this.activeRouteCommand.state, AICommandState.Failure)
      || Equals(this.activeRouteCommand.state, AICommandState.Cancelled)
      || Equals(this.activeRouteCommand.state, AICommandState.Interrupted);
  }
'''
new=r'''  public func IsRouteCommandFailed() -> Bool {
    if IsDefined(this.activeSplineCommand) {
      return Equals(this.activeSplineCommand.state, AICommandState.Failure)
        || Equals(this.activeSplineCommand.state, AICommandState.Cancelled)
        || Equals(this.activeSplineCommand.state, AICommandState.Interrupted);
    };
    if !IsDefined(this.activeRouteCommand) { return false; };
    return Equals(this.activeRouteCommand.state, AICommandState.Failure)
      || Equals(this.activeRouteCommand.state, AICommandState.Cancelled)
      || Equals(this.activeRouteCommand.state, AICommandState.Interrupted);
  }
'''
if old not in text: raise SystemExit('IsRouteCommandFailed block missing')
text=text.replace(old,new,1)

SRC.write_text(text,encoding='utf-8',newline='\n')

P1=(-2161.015,-1012.713,7.851)
P2=(-2162.260,-1043.903,7.846)
dx=P2[0]-P1[0]; dy=P2[1]-P1[1]
L=math.hypot(dx,dy)
f=(dx/L,dy/L); r=(-f[1],f[0])
svc=(P1[0]+0.65*dx,P1[1]+0.65*dy,P1[2]+0.65*(P2[2]-P1[2]))
def worldpt(d,lat,z=None):
    return (P1[0]+f[0]*d+r[0]*lat, P1[1]+f[1]*d+r[1]*lat, P1[2] if z is None else z)
entry=[worldpt(-30,4.2),worldpt(-18,4.2),worldpt(-8,3.7),worldpt(0,2.2),worldpt(8,0.7),worldpt(16,0.1),svc]
exitp=[svc,worldpt(25,0.0),worldpt(L,1.2),worldpt(L+6,3.0),worldpt(L+14.7,4.2),worldpt(L+24,4.2)]

def defs(points):
    out=[]; n=len(points)
    for i,p in enumerate(points):
        if i==0: v=tuple((points[1][a]-p[a])/3 for a in range(3))
        elif i==n-1: v=tuple((p[a]-points[i-1][a])/3 for a in range(3))
        else: v=tuple((points[i+1][a]-points[i-1][a])/6 for a in range(3))
        out.append((p,tuple(-x for x in v),v))
    return out

def vec3(v): return {'$type':'Vector3','X':v[0],'Y':v[1],'Z':v[2]}
def vec4(v,w=0): return {'$type':'Vector4','W':w,'X':v[0],'Y':v[1],'Z':v[2]}
def noderef(s): return {'$type':'NodeRef','$storage':'string','$value':s}
def cname(s): return {'$type':'CName','$storage':'string','$value':s}
def point_json(p,tin,tout,anchor):
    rel=tuple(p[a]-anchor[a] for a in range(3))
    return {'$type':'SplinePoint','automaticTangents':0,'continuousTangents':1,'id':0,'position':vec3(rel),'rotation':{'$type':'Quaternion','i':0,'j':0,'k':0,'r':1},'tangents':{'Elements':[vec3(tin),vec3(tout)]}}
def spline_node(name,points,anchor,handle):
    ps=[point_json(*d,anchor) for d in defs(points)]
    return {'HandleId':str(handle),'Data':{'$type':'worldSplineNode','debugName':cname(name),'destSnapedNode':{'$type':'NodeRef','$storage':'uint64','$value':'0'},'destSnapedSocketName':cname('None'),'entrySnapedNode':{'$type':'NodeRef','$storage':'uint64','$value':'0'},'entrySnapedSocketName':cname('None'),'isHostOnly':0,'isVisibleInGame':1,'proxyScale':None,'sourcePrefabHash':'0','splineData':{'HandleId':str(handle+1),'Data':{'$type':'Spline','hasDirection':1,'looped':0,'points':ps,'reversed':0}},'tag':'None','tagExt':'None'}}
def node_data(idx,ref,anchor,points):
    xs=[p[0] for p in points]; ys=[p[1] for p in points]; zs=[p[2] for p in points]
    return {'Id':'0','NodeIndex':idx,'Position':vec4(anchor),'Orientation':{'$type':'Quaternion','i':0,'j':0,'k':0,'r':1},'Scale':vec3((1,1,1)),'Pivot':vec3(anchor),'Bounds':{'$type':'Box','Max':vec4((max(xs),max(ys),max(zs))),'Min':vec4((min(xs),min(ys),min(zs))),'Flags':'Default'} if False else {'$type':'Box','Max':vec4((max(xs),max(ys),max(zs))),'Min':vec4((min(xs),min(ys),min(zs)))},'QuestPrefabRefHash':noderef(ref),'UkHash1':{'$type':'NodeRef','$storage':'uint64','$value':'0'},'CookedPrefabData':{'DepotPath':{'$type':'ResourcePath','$storage':'uint64','$value':'0'},'Flags':'Default'},'MaxStreamingDistance':300.0,'UkFloat1':100.0,'Uk10':1056,'Uk11':10762,'Uk12':0,'Uk13':'0','Uk14':'0'}

ENTRY_REF='$/03_night_city/#nctc/#h2_bay_entry'; EXIT_REF='$/03_night_city/#nctc/#h2_bay_exit'; anchor=P1
header=lambda n:{'WolvenKitVersion':'9.0.1','WKitJsonVersion':'0.0.9','GameVersion':2310,'DataType':'CR2W','ArchiveFileName':n}
sector={'Header':header('h2_bay.streamingsector'),'Data':{'Version':195,'BuildVersion':0,'RootChunk':{'$type':'worldStreamingSector','category':'Exterior','cookingPlatform':'PLATFORM_PC','externInplaceResource':{'DepotPath':{'$type':'ResourcePath','$storage':'uint64','$value':'0'},'Flags':'Soft'},'level':1,'localInplaceResource':[],'nodeData':{'BufferId':'0','Flags':4063232,'Type':'WolvenKit.RED4.Archive.Buffer.worldNodeDataBuffer, WolvenKit.RED4, Version=9.0.1.0, Culture=neutral, PublicKeyToken=null','Data':[node_data(0,ENTRY_REF,anchor,entry),node_data(1,EXIT_REF,anchor,exitp)]},'nodeRefs':[noderef(ENTRY_REF),noderef(EXIT_REF)],'nodes':[spline_node('{nctc_h2_bay_entry}',entry,anchor,0),spline_node('{nctc_h2_bay_exit}',exitp,anchor,2)],'persistentNodeIndex':0,'persistentNodes':[],'variantIndices':[0],'variantNodes':[],'version':62},'EmbeddedFiles':[]}}
level=1; cellm=64*(2**level); S=2**(8-level); half=S//2
i,j,k=[math.floor(c/cellm) for c in anchor]; grid=(i+half)+S*(j+half)+S*S*(k+half); margin=320.0
block={'Header':header('h2_bay.streamingblock'),'Data':{'Version':195,'BuildVersion':0,'RootChunk':{'$type':'worldStreamingBlock','cookingPlatform':'PLATFORM_PC','descriptors':[{'$type':'worldStreamingSectorDescriptor','blockIndex':{'$type':'worldStreamingBlockIndex','oup':'Base','rldGridCell':grid},'category':'Exterior','data':{'DepotPath':{'$type':'ResourcePath','$storage':'string','$value':'nctc\\h2\\h2_bay.streamingsector'},'Flags':'Soft'},'level':1,'numNodeRanges':1,'questPrefabNodeRef':{'$type':'NodeRef','$storage':'uint64','$value':'0'},'streamingBox':{'$type':'Box','Max':vec4((anchor[0]+margin,anchor[1]+margin,anchor[2]+margin),1),'Min':vec4((anchor[0]-margin,anchor[1]-margin,anchor[2]-margin),1)},'variants':[]}],'index':{'$type':'worldStreamingBlockIndex','oup':'Base','rldGridCell':0}},'EmbeddedFiles':[]}}
raw=ROOT/'build/raw/nctc/h2'; raw.mkdir(parents=True,exist_ok=True)
(raw/'h2_bay.streamingsector.json').write_text(json.dumps(sector,indent=2),encoding='utf-8',newline='\n')
(raw/'h2_bay.streamingblock.json').write_text(json.dumps(block,indent=2),encoding='utf-8',newline='\n')
(ROOT/'build/NCTCBaySplinePrototype.archive.xl').write_text('streaming:\n  blocks:\n    - nctc\\h2\\h2_bay.streamingblock\n',encoding='utf-8',newline='\n')
print('r376a source patched; H2 native spline resources generated')
