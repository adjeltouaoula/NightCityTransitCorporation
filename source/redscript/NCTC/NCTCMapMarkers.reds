module NCTC

public class NCTCMarkerRefreshCallback extends DelayCallback {
  private let system: wref<NCTCMapMarkerSystem>;

  public func Configure(system: ref<NCTCMapMarkerSystem>) -> Void {
    this.system = system;
  }

  public func Call() -> Void {
    if IsDefined(this.system) { this.system.RegisterAllMarkers(); };
  }
}

public struct NCTCStopDefinition {
  public let locKey: String;
  public let line: String;
  public let stop: String;
}

public struct NCTCTravelAnchor {
  public let position: Vector4;
  public let locKey: String;
}

public class NCTCStopMappinData extends MappinScriptData {
  public let line: String;
  public let services: String;
  public let serviceLines: array<String>;
  public let serviceStops: array<String>;
  public let isHub: Bool;
}

public class NCTCMapMarkerSystem extends ScriptableSystem {
  private let m_registeredMappins: array<NewMappinID>;
  private let m_servicePositions: array<Vector4>;
  private let m_serviceLines: array<String>;

  public static func GetInstance(game: GameInstance) -> ref<NCTCMapMarkerSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<NCTCMapMarkerSystem>()) as NCTCMapMarkerSystem;
  }

  private func Stop(line: String, locKey: String, stop: String) -> NCTCStopDefinition {
    let definition: NCTCStopDefinition;
    definition.line = line;
    definition.locKey = locKey;
    definition.stop = stop;
    return definition;
  }

  // The network is anchored directly to native fast-travel / NCART LocKeys.
  // No district coordinates and no "nearest station" fallback are used.
  private func GetStops() -> array<NCTCStopDefinition> {
    let stops: array<NCTCStopDefinition>;

    // 17
    ArrayPush(stops, this.Stop("17", "LocKey#44536", "QG Delamain"));
    ArrayPush(stops, this.Stop("17", "LocKey#44531", "Petrel Street"));
    ArrayPush(stops, this.Stop("17", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("17", "LocKey#44534", "Congress & Madison"));
    ArrayPush(stops, this.Stop("17", "LocKey#44532", "College Street"));
    ArrayPush(stops, this.Stop("17", "LocKey#44533", "Skyline Est"));
    ArrayPush(stops, this.Stop("17", "LocKey#44536", "QG Delamain"));

    // 22
    ArrayPush(stops, this.Stop("22", "LocKey#44695", "Sarsati & Republic"));
    ArrayPush(stops, this.Stop("22", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("22", "LocKey#52544", "Memorial Park"));
    ArrayPush(stops, this.Stop("22", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("22", "LocKey#44536", "QG Delamain"));
    ArrayPush(stops, this.Stop("22", "LocKey#44531", "Petrel Street"));
    ArrayPush(stops, this.Stop("22", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("22", "LocKey#44695", "Sarsati & Republic"));

    // 23
    ArrayPush(stops, this.Stop("23", "LocKey#52544", "Memorial Park"));
    ArrayPush(stops, this.Stop("23", "LocKey#44534", "Congress & Madison"));
    ArrayPush(stops, this.Stop("23", "LocKey#44532", "College Street"));
    ArrayPush(stops, this.Stop("23", "LocKey#44533", "Skyline Est"));
    ArrayPush(stops, this.Stop("23", "LocKey#44530", "Republic and Vine"));
    ArrayPush(stops, this.Stop("23", "LocKey#44531", "Petrel Street"));
    ArrayPush(stops, this.Stop("23", "LocKey#44536", "QG Delamain"));
    ArrayPush(stops, this.Stop("23", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("23", "LocKey#52544", "Memorial Park"));

    // 51
    ArrayPush(stops, this.Stop("51", "LocKey#44679", "Wellsprings"));
    ArrayPush(stops, this.Stop("51", "LocKey#44533", "Skyline Est"));
    ArrayPush(stops, this.Stop("51", "LocKey#44532", "College Street"));
    ArrayPush(stops, this.Stop("51", "LocKey#44534", "Congress & Madison"));
    ArrayPush(stops, this.Stop("51", "LocKey#44515", "Senate and Market"));
    ArrayPush(stops, this.Stop("51", "LocKey#44679", "Wellsprings"));

    // 68
    ArrayPush(stops, this.Stop("68", "LocKey#44695", "Sarsati & Republic"));
    ArrayPush(stops, this.Stop("68", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("68", "LocKey#52544", "Memorial Park"));
    ArrayPush(stops, this.Stop("68", "LocKey#44501", "Cannery Plaza"));
    ArrayPush(stops, this.Stop("68", "LocKey#44515", "Senate and Market"));
    ArrayPush(stops, this.Stop("68", "LocKey#44534", "Congress & Madison"));
    ArrayPush(stops, this.Stop("68", "LocKey#44532", "College Street"));
    ArrayPush(stops, this.Stop("68", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("68", "LocKey#44695", "Sarsati & Republic"));

    // 72
    ArrayPush(stops, this.Stop("72", "LocKey#44679", "Wellsprings"));
    ArrayPush(stops, this.Stop("72", "LocKey#44515", "Senate and Market"));
    ArrayPush(stops, this.Stop("72", "LocKey#44501", "Cannery Plaza"));
    ArrayPush(stops, this.Stop("72", "LocKey#44473", "Marina de Gold Beach"));
    ArrayPush(stops, this.Stop("72", "LocKey#44700", "Alexander Street"));
    ArrayPush(stops, this.Stop("72", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("72", "LocKey#44695", "Sarsati & Republic"));
    ArrayPush(stops, this.Stop("72", "LocKey#44485", "Rocade"));
    ArrayPush(stops, this.Stop("72", "LocKey#44531", "Petrel Street"));
    ArrayPush(stops, this.Stop("72", "LocKey#44679", "Wellsprings"));
    return stops;
  }

  private func GetTravelAnchors(system: ref<MappinSystem>) -> array<NCTCTravelAnchor> {
    let anchors: array<NCTCTravelAnchor>;
    let mappins: array<ref<IMappin>> = system.GetAllMappins();
    let mappin: ref<IMappin>;
    let travel: ref<FastTravelMappin>;
    let anchor: NCTCTravelAnchor;
    let index: Int32 = 0;
    while index < ArraySize(mappins) {
      mappin = mappins[index];
      if IsDefined(mappin) && (Equals(mappin.GetVariant(), gamedataMappinVariant.FastTravelVariant) || Equals(mappin.GetVariant(), gamedataMappinVariant.Zzz17_NCARTVariant)) {
        travel = mappin as FastTravelMappin;
        if IsDefined(travel) {
          anchor.position = travel.GetWorldPosition();
          anchor.locKey = travel.GetPointData().GetPointDisplayName();
          ArrayPush(anchors, anchor);
        };
      };
      index += 1;
    };
    return anchors;
  }

  private func FindAnchor(anchors: array<NCTCTravelAnchor>, locKey: String) -> Int32 {
    let index: Int32 = 0;
    while index < ArraySize(anchors) {
      if Equals(anchors[index].locKey, locKey) { return index; };
      index += 1;
    };
    return -1;
  }

  private func FindHub(positions: array<Vector4>, position: Vector4) -> Int32 {
    let index: Int32 = 0;
    while index < ArraySize(positions) {
      if Vector4.Distance2D(positions[index], position) < 1.00 { return index; };
      index += 1;
    };
    return -1;
  }

  public func GetNearestService(position: Vector4, out line: String, out stop: Vector4) -> Bool {
    let index: Int32 = 0;
    let nearest: Int32 = -1;
    let nearestDistance: Float = 18.00;
    let distance: Float;
    while index < ArraySize(this.m_servicePositions) {
      distance = Vector4.Distance(position, this.m_servicePositions[index]);
      if distance < nearestDistance {
        nearestDistance = distance;
        nearest = index;
      };
      index += 1;
    };
    if nearest < 0 { return false; };
    line = this.m_serviceLines[nearest];
    stop = this.m_servicePositions[nearest];
    return true;
  }

  public func RegisterAllMarkers() -> Void {
    let data: MappinData;
    let markerData: ref<NCTCStopMappinData>;
    let system: ref<MappinSystem>;
    let stops: array<NCTCStopDefinition>;
    let anchors: array<NCTCTravelAnchor>;
    let positions: array<Vector4>;
    let services: array<String>;
    let lines: array<String>;
    let hubServiceLines: array<array<String>>;
    let hubServiceStops: array<array<String>>;
    let counts: array<Int32>;
    let service: String;
    let anchorIndex: Int32;
    let hubIndex: Int32;
    let stopIndex: Int32 = 0;
    let index: Int32 = 0;

    this.UnregisterAllMarkers();
    system = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(system) { return; };
    stops = this.GetStops();
    anchors = this.GetTravelAnchors(system);
    while stopIndex < ArraySize(stops) {
      anchorIndex = this.FindAnchor(anchors, stops[stopIndex].locKey);
      if anchorIndex >= 0 {
        service = "NCTC " + stops[stopIndex].line + " — " + stops[stopIndex].stop;
        hubIndex = this.FindHub(positions, anchors[anchorIndex].position);
        if hubIndex < 0 {
          ArrayPush(positions, anchors[anchorIndex].position);
          ArrayPush(services, service);
          ArrayPush(lines, stops[stopIndex].line);
          ArrayPush(hubServiceLines, [stops[stopIndex].line]);
          ArrayPush(hubServiceStops, [stops[stopIndex].stop]);
          ArrayPush(counts, 1);
        } else if !StrContains(services[hubIndex], service) {
          services[hubIndex] += "\n" + service;
          ArrayPush(hubServiceLines[hubIndex], stops[stopIndex].line);
          ArrayPush(hubServiceStops[hubIndex], stops[stopIndex].stop);
          counts[hubIndex] += 1;
        };
      };
      stopIndex += 1;
    };

    index = 0;
    while index < ArraySize(positions) {
      markerData = new NCTCStopMappinData();
      markerData.services = services[index];
      markerData.serviceLines = hubServiceLines[index];
      markerData.serviceStops = hubServiceStops[index];
      markerData.isHub = counts[index] > 1;
      markerData.line = lines[index];
      if markerData.isHub { markerData.line = "HUB"; };
      data.mappinType = t"Mappins.NCTCStopMappinDefinition";
      data.variant = gamedataMappinVariant.CPO_PingDoorVariant;
      data.active = true;
      data.scriptData = markerData;
      ArrayPush(this.m_registeredMappins, system.RegisterMappin(data, positions[index]));
      index += 1;
    };
    this.m_servicePositions = positions;
    this.m_serviceLines = lines;
  }

  public func UnregisterAllMarkers() -> Void {
    let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
    if IsDefined(system) { for id in this.m_registeredMappins { system.UnregisterMappin(id); }; };
    ArrayClear(this.m_registeredMappins);
    ArrayClear(this.m_servicePositions);
    ArrayClear(this.m_serviceLines);
  }
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let system: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGame());
  let callback: ref<NCTCMarkerRefreshCallback>;
  if IsDefined(system) {
    system.RegisterAllMarkers();
    callback = new NCTCMarkerRefreshCallback();
    callback.Configure(system);
    GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(callback, 3.00, false);
  };
  return result;
}

// Fast-travel and NCART mappins are populated after the player is attached.
// Register again once the world map exists so the LocKey anchors are available.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  let player: ref<PlayerPuppet> = this.GetPlayerControlledObject() as PlayerPuppet;
  let system: ref<NCTCMapMarkerSystem>;
  if IsDefined(player) {
    system = NCTCMapMarkerSystem.GetInstance(player.GetGame());
    if IsDefined(system) { system.RegisterAllMarkers(); };
  };
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  let system: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGame());
  if IsDefined(system) { system.UnregisterAllMarkers(); };
  return wrappedMethod();
}

@addMethod(BaseMappinBaseController)
protected final func ApplyNCTCStopIcon(line: String) -> Void {
  let icon: wref<inkImage>;
  let color: CName = n"MainColors.White";
  let customOrange: Bool = false;
  let customPink: Bool = false;
  let customHub: Bool = false;
  switch line {
    case "17": customOrange = true; break;
    case "22": color = n"MainColors.Yellow"; break;
    case "23": customPink = true; break;
    case "51": color = n"MainColors.Green"; break;
    case "68": color = n"MainColors.Purple"; break;
    case "72": color = n"MainColors.Blue"; break;
    case "HUB": customHub = true; break;
  };
  inkImageRef.SetAtlasResource(this.iconWidget, r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
  inkImageRef.SetTexturePart(this.iconWidget, n"fast_travel");
  icon = inkImageRef.Get(this.iconWidget) as inkImage;
  if IsDefined(icon) {
    icon.UnbindProperty(n"tintColor");
    if customOrange { icon.SetTintColor(new HDRColor(1.28, 0.32, 0.00, 1.00)); }
    else if customPink { icon.SetTintColor(new HDRColor(1.00, 0.25, 0.65, 1.00)); }
    else if customHub { icon.SetTintColor(new HDRColor(0.37, 0.96, 1.00, 1.00)); }
    else { icon.BindProperty(n"tintColor", color); };
  };
}

@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  let data: ref<NCTCStopMappinData> = this.GetMappin().GetScriptData() as NCTCStopMappinData;
  if IsDefined(data) { this.ApplyNCTCStopIcon(data.line); };
}

@wrapMethod(WorldMapTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
  let stopData: ref<NCTCStopMappinData>;
  let desc: ref<inkText>;
  let parent: ref<inkCompoundWidget>;
  let panel: ref<inkVerticalPanel>;
  let serviceText: ref<inkText>;
  let index: Int32 = 0;
  wrappedMethod(data, menu);
  desc = inkTextRef.Get(this.m_descText) as inkText;
  if IsDefined(this.nctcHubLines) { this.nctcHubLines.SetVisible(false); };
  if !IsDefined(Deref(data).mappin) { return; };
  stopData = Deref(data).mappin.GetScriptData() as NCTCStopMappinData;
  if IsDefined(stopData) {
    if stopData.isHub { inkTextRef.SetText(this.m_titleText, "NCTC Transit Hub"); }
    else { inkTextRef.SetText(this.m_titleText, stopData.services); };
    inkTextRef.SetText(this.m_descText, stopData.services);
    if stopData.isHub && IsDefined(desc) {
      parent = desc.GetParentWidget() as inkCompoundWidget;
      if IsDefined(parent) {
        if !IsDefined(this.nctcHubLines) {
          panel = new inkVerticalPanel();
          panel.SetName(n"NCTCHubLines");
          panel.SetFitToContent(true);
          panel.Reparent(parent);
          this.nctcHubLines = panel;
        };
        this.nctcHubLines.RemoveAllChildren();
        while index < ArraySize(stopData.serviceLines) {
          serviceText = new inkText();
          serviceText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
          serviceText.SetFontSize(inkTextRef.GetFontSize(this.m_descText));
          serviceText.SetFontStyle(inkTextRef.GetFontStyle(this.m_descText));
          serviceText.SetLetterCase(textLetterCase.OriginalCase);
          serviceText.SetStyle(r"base\\gameplay\\gui\\common\\main_colors.inkstyle");
          serviceText.SetText("NCTC " + stopData.serviceLines[index] + " — " + stopData.serviceStops[index]);
          serviceText.SetTintColor(NCTCHubLineColor(stopData.serviceLines[index]));
          serviceText.Reparent(this.nctcHubLines);
          index += 1;
        };
        desc.SetVisible(false);
        this.nctcHubLines.SetVisible(true);
      };
    } else if IsDefined(desc) {
      desc.SetVisible(true);
    };
  };
}

@addField(WorldMapTooltipController)
let nctcHubLines: wref<inkVerticalPanel>;

public func NCTCHubLineColor(line: String) -> HDRColor {
  switch line {
    case "17": return new HDRColor(1.28, 0.32, 0.00, 1.00);
    case "22": return new HDRColor(1.00, 0.86, 0.08, 1.00);
    case "23": return new HDRColor(1.00, 0.25, 0.65, 1.00);
    case "51": return new HDRColor(0.20, 0.90, 0.42, 1.00);
    case "68": return new HDRColor(0.70, 0.38, 1.00, 1.00);
    case "72": return new HDRColor(0.20, 0.55, 1.00, 1.00);
  };
  return new HDRColor(1.00, 1.00, 1.00, 1.00);
}
