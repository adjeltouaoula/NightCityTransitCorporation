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
  public let position: Vector4;
  public let isManual: Bool;
  public let color: Int32;
}

public struct NCTCTravelAnchor {
  public let position: Vector4;
  public let locKey: String;
  public let isMetro: Bool;
}

public class NCTCStopMappinData extends MappinScriptData {
  public let line: String;
  public let services: String;
  public let serviceLines: array<String>;
  public let serviceStops: array<String>;
  public let isHub: Bool;
  public let color: Int32;
  public let serviceColors: array<Int32>;
}

public class NCTCMapMarkerSystem extends ScriptableSystem {
  private let m_registeredMappins: array<NewMappinID>;
  private let m_servicePositions: array<Vector4>;
  private let m_serviceLines: array<String>;
  private let m_serviceHubLines: array<array<String>>;
  private let m_serviceHubStops: array<array<String>>;

  public static func GetInstance(game: GameInstance) -> ref<NCTCMapMarkerSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<NCTCMapMarkerSystem>()) as NCTCMapMarkerSystem;
  }

  private func Stop(line: String, locKey: String, stop: String) -> NCTCStopDefinition {
    let definition: NCTCStopDefinition;
    definition.line = line;
    definition.locKey = locKey;
    definition.stop = stop;
    definition.position = Vector4.EmptyVector();
    definition.isManual = false;
    definition.color = -1;
    return definition;
  }

  private func ManualStop(line: String, position: Vector4, stop: String) -> NCTCStopDefinition {
    let definition: NCTCStopDefinition;
    definition.line = line;
    definition.locKey = "";
    definition.stop = stop;
    definition.position = position;
    definition.isManual = true;
    definition.color = -1;
    return definition;
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
          anchor.isMetro = Equals(mappin.GetVariant(), gamedataMappinVariant.Zzz17_NCARTVariant);
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
      if Vector4.Distance2D(positions[index], position) < 20.00 { return index; };
      index += 1;
    };
    return -1;
  }

  // Roadside/manual stops may be deliberately offset from a terminal so they
  // can sit on a valid bus lane. Search a full city block (300m); within that
  // radius, an NCART station wins over a fast-travel point.
  private func GetManualStopName(position: Vector4) -> String {
    let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
    let anchors: array<NCTCTravelAnchor>;
    let index: Int32 = 0;
    let nearest: Int32 = -1;
    let nearestMetro: Int32 = -1;
    let nearestDistance: Float = 300.00;
    let nearestMetroDistance: Float = 300.00;
    let distance: Float;
    if !IsDefined(system) { return "Survey stop"; };
    anchors = this.GetTravelAnchors(system);
    while index < ArraySize(anchors) {
      distance = Vector4.Distance(position, anchors[index].position);
      if distance < nearestDistance { nearest = index; nearestDistance = distance; };
      if anchors[index].isMetro && distance < nearestMetroDistance { nearestMetro = index; nearestMetroDistance = distance; };
      index += 1;
    };
    if nearestMetro >= 0 { return GetLocalizedText(anchors[nearestMetro].locKey); };
    if nearest >= 0 { return GetLocalizedText(anchors[nearest].locKey); };
    return "Survey stop";
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

  public func GetNearestTravelAnchor(position: Vector4, out locKey: String, out anchorPosition: Vector4) -> Bool {
    let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
    let anchors: array<NCTCTravelAnchor>;
    let index: Int32 = 0;
    let nearest: Int32 = -1;
    let distance: Float;
    let nearestDistance: Float = 12.00;
    if !IsDefined(system) { return false; };
    anchors = this.GetTravelAnchors(system);
    while index < ArraySize(anchors) {
      distance = Vector4.Distance(position, anchors[index].position);
      if distance < nearestDistance { nearestDistance = distance; nearest = index; };
      index += 1;
    };
    if nearest < 0 { return false; };
    locKey = anchors[nearest].locKey; anchorPosition = anchors[nearest].position;
    return true;
  }

  private func GetExternalStops() -> array<NCTCStopDefinition> {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let stops: array<NCTCStopDefinition>;
    let count: Int32;
    let index: Int32 = 0;
    let prefix: String;
    let line: Int32;
    let locKey: Int32;
    let definition: NCTCStopDefinition;
    if !IsDefined(quests) || !Equals(quests.GetFact(n"nctc_external_network_ready"), 1) { return stops; };
    count = quests.GetFact(n"nctc_external_network_stop_count");
    while index < count {
      prefix = "nctc_external_stop_" + ToString(index) + "_";
      line = quests.GetFact(StringToName(prefix + "line"));
      locKey = quests.GetFact(StringToName(prefix + "loc_key"));
      if locKey > 0 {
        definition = this.Stop(ToString(line), "LocKey#" + ToString(locKey), GetLocalizedText("LocKey#" + ToString(locKey)));
      } else {
        definition = this.ManualStop(ToString(line), new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "x"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "y"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "z"))) / 1000.00, 1.00), this.GetManualStopName(new Vector4(Cast<Float>(quests.GetFact(StringToName(prefix + "x"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "y"))) / 1000.00, Cast<Float>(quests.GetFact(StringToName(prefix + "z"))) / 1000.00, 1.00)));
      };
      definition.color = quests.GetFact(StringToName("nctc_external_line_" + ToString(line) + "_color"));
      ArrayPush(stops, definition);
      index += 1;
    };
    return stops;
  }

  private func GetNetworkStops() -> array<NCTCStopDefinition> {
    // The external JSON network is the sole runtime source.
    return this.GetExternalStops();
  }

  public func GetNearestStopServices(position: Vector4, out lines: array<String>, out stops: array<String>) -> Bool {
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
    lines = this.m_serviceHubLines[nearest];
    stops = this.m_serviceHubStops[nearest];
    return true;
  }

  // Used by the physical fast-travel terminal screen.  Unlike the map-marker
  // cache, this is also safe while the world map is not open yet.
  public func GetServicesForLocKey(locKey: String, out lines: array<String>, out stops: array<String>) -> Bool {
    let definitions: array<NCTCStopDefinition> = this.GetNetworkStops();
    let index: Int32 = 0;
    let knownLines: String = "|";
    while index < ArraySize(definitions) {
      if Equals(definitions[index].locKey, locKey) && !StrContains(knownLines, "|" + definitions[index].line + "|") {
        ArrayPush(lines, definitions[index].line);
        ArrayPush(stops, definitions[index].stop);
        knownLines += definitions[index].line + "|";
      };
      index += 1;
    };
    return ArraySize(lines) > 0;
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
    let hubServiceColors: array<array<Int32>>;
    let counts: array<Int32>;
    let service: String;
    let anchorIndex: Int32;
    let hubIndex: Int32;
    let stopIndex: Int32 = 0;
    let index: Int32 = 0;

    this.UnregisterAllMarkers();
    system = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(system) { return; };
    stops = this.GetNetworkStops();
    anchors = this.GetTravelAnchors(system);
    while stopIndex < ArraySize(stops) {
      anchorIndex = this.FindAnchor(anchors, stops[stopIndex].locKey);
      if stops[stopIndex].isManual {
        anchorIndex = -1;
        service = "NCTC " + stops[stopIndex].line + " — " + stops[stopIndex].stop;
        hubIndex = this.FindHub(positions, stops[stopIndex].position);
        if hubIndex < 0 {
          ArrayPush(positions, stops[stopIndex].position);
          ArrayPush(services, service);
          ArrayPush(lines, stops[stopIndex].line);
          ArrayPush(hubServiceLines, [stops[stopIndex].line]);
          ArrayPush(hubServiceStops, [stops[stopIndex].stop]);
          ArrayPush(hubServiceColors, [stops[stopIndex].color]);
          ArrayPush(counts, 1);
        } else if !StrContains(services[hubIndex], service) {
          services[hubIndex] += "\n" + service;
          ArrayPush(hubServiceLines[hubIndex], stops[stopIndex].line);
          ArrayPush(hubServiceStops[hubIndex], stops[stopIndex].stop);
          ArrayPush(hubServiceColors[hubIndex], stops[stopIndex].color);
          counts[hubIndex] += 1;
        };
      } else if anchorIndex >= 0 {
        service = "NCTC " + stops[stopIndex].line + " — " + stops[stopIndex].stop;
        hubIndex = this.FindHub(positions, anchors[anchorIndex].position);
        if hubIndex < 0 {
          ArrayPush(positions, anchors[anchorIndex].position);
          ArrayPush(services, service);
          ArrayPush(lines, stops[stopIndex].line);
          ArrayPush(hubServiceLines, [stops[stopIndex].line]);
          ArrayPush(hubServiceStops, [stops[stopIndex].stop]);
          ArrayPush(hubServiceColors, [stops[stopIndex].color]);
          ArrayPush(counts, 1);
        } else if !StrContains(services[hubIndex], service) {
          services[hubIndex] += "\n" + service;
          ArrayPush(hubServiceLines[hubIndex], stops[stopIndex].line);
          ArrayPush(hubServiceStops[hubIndex], stops[stopIndex].stop);
          ArrayPush(hubServiceColors[hubIndex], stops[stopIndex].color);
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
      markerData.serviceColors = hubServiceColors[index];
      markerData.isHub = counts[index] > 1;
      markerData.line = lines[index];
      markerData.color = hubServiceColors[index][0];
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
    this.m_serviceHubLines = hubServiceLines;
    this.m_serviceHubStops = hubServiceStops;
  }

  public func UnregisterAllMarkers() -> Void {
    let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
    if IsDefined(system) { for id in this.m_registeredMappins { system.UnregisterMappin(id); }; };
    ArrayClear(this.m_registeredMappins);
    ArrayClear(this.m_servicePositions);
    ArrayClear(this.m_serviceLines);
    ArrayClear(this.m_serviceHubLines);
    ArrayClear(this.m_serviceHubStops);
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
protected final func ApplyNCTCStopIcon(line: String, lineColor: Int32) -> Void {
  let icon: wref<inkImage>;
  let customHub: Bool = false;
  if Equals(line, "HUB") { customHub = true; };
  inkImageRef.SetAtlasResource(this.iconWidget, r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
  inkImageRef.SetTexturePart(this.iconWidget, n"fast_travel");
  icon = inkImageRef.Get(this.iconWidget) as inkImage;
  if IsDefined(icon) {
    icon.UnbindProperty(n"tintColor");
    if customHub { icon.SetTintColor(new HDRColor(0.37, 0.96, 1.00, 1.00)); }
    else { icon.SetTintColor(NCTCLineColor(lineColor)); };
  };
}

@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  let data: ref<NCTCStopMappinData> = this.GetMappin().GetScriptData() as NCTCStopMappinData;
  if IsDefined(data) { this.ApplyNCTCStopIcon(data.line, data.color); };
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
          serviceText.SetTintColor(NCTCLineColor(stopData.serviceColors[index]));
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

public func NCTCLineColor(color: Int32) -> HDRColor {
  switch color {
    case 0: return new HDRColor(1.28, 0.32, 0.00, 1.00);
    case 1: return new HDRColor(1.00, 0.86, 0.08, 1.00);
    case 2: return new HDRColor(1.00, 0.25, 0.65, 1.00);
    case 3: return new HDRColor(0.20, 0.90, 0.42, 1.00);
    case 4: return new HDRColor(0.70, 0.38, 1.00, 1.00);
    case 5: return new HDRColor(0.20, 0.55, 1.00, 1.00);
    case 6: return new HDRColor(1.00, 0.18, 0.18, 1.00);
  };
  return new HDRColor(1.00, 1.00, 1.00, 1.00);
}
