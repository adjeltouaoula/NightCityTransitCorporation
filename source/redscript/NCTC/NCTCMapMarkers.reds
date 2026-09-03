module NCTC

public struct NCTCStopDefinition {
  public let position: Vector4;
  public let line: String;
  public let stop: String;
}

public class NCTCStopMappinData extends MappinScriptData {
  public let line: String;
  public let stop: String;
  public let services: String;
  public let isHub: Bool;
}

public struct NCTCTravelAnchor {
  public let position: Vector4;
  public let locKey: String;
  public let displayName: String;
}

public class NCTCMapMarkerSystem extends ScriptableSystem {
  private let m_registeredMappins: array<NewMappinID>;

  public static func GetInstance(game: GameInstance) -> ref<NCTCMapMarkerSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<NCTCMapMarkerSystem>()) as NCTCMapMarkerSystem;
  }

  private func Stop(x: Float, y: Float, z: Float, line: String, stop: String) -> NCTCStopDefinition {
    let definition: NCTCStopDefinition;
    definition.position = new Vector4(x, y, z, 1.00);
    definition.line = line;
    definition.stop = stop;
    return definition;
  }

  private func DisplayStopName(stop: String) -> String {
    switch stop {
      case "Old Downtown": return "Centre ville";
      case "City Center": return "Centre ville";
      case "Upper Marina": return "Marina Gold Beach";
      case "East Marina": return "Marina Gold Beach";
      case "Upper Eastside": return "Corporation Street";
      case "Medical Center": return "Métro Med Center";
      case "Bank Block": return "Tour Arasaka";
      case "Japantown": return "Marché des fleurs de cerisier";
      case "Little China": return "Martin Street";
      case "Corporate Center": return "Memorial Park";
      case "New Harbor": return "Métro Megabuilding H10";
      case "Charter Hill": return "Métro Charter Hill";
      case "South Night City": return "Métro Glen Sud";
      case "University District": return "College Street";
      case "West Hill": return "Métro Charter Hill";
      case "Northside": return "Centre ville nord";
      case "Studio City": return "Alexander Street";
      case "Little Italy": return "6th Street West Station";
    };
    return stop;
  }

  private func GetTravelAnchors(system: ref<MappinSystem>) -> array<NCTCTravelAnchor> {
    let anchors: array<NCTCTravelAnchor>;
    let mappins: array<ref<IMappin>> = system.GetAllMappins();
    let mappin: ref<IMappin>;
    let anchor: NCTCTravelAnchor;
    let travel: ref<FastTravelMappin>;
    let index: Int32 = 0;
    while index < ArraySize(mappins) {
      mappin = mappins[index];
      if IsDefined(mappin) && (Equals(mappin.GetVariant(), gamedataMappinVariant.FastTravelVariant) || Equals(mappin.GetVariant(), gamedataMappinVariant.Zzz17_NCARTVariant)) {
        travel = mappin as FastTravelMappin;
        if IsDefined(travel) {
          anchor.position = travel.GetWorldPosition();
          anchor.locKey = travel.GetPointData().GetPointDisplayName();
          anchor.displayName = GetLocalizedText(anchor.locKey);
          ArrayPush(anchors, anchor);
        };
      };
      index += 1;
    };
    return anchors;
  }

  private func RequiredLocKey(stop: String) -> String {
    switch stop {
      case "Medical Center": return "LocKey#44728";
      case "Bank Block": return "LocKey#52544";
      case "New Harbor": return "LocKey#52585";
      case "Charter Hill": return "LocKey#52574";
      case "West Hill": return "LocKey#52574";
      case "South Night City": return "LocKey#44676";
    };
    return "";
  }

  // Exact anchor lookup only. It never substitutes a nearby terminal.
  private func ResolveAnchor(stop: NCTCStopDefinition, anchors: array<NCTCTravelAnchor>) -> Int32 {
    let targetName: String = this.DisplayStopName(stop.stop);
    let targetLocKey: String = this.RequiredLocKey(stop.stop);
    let index: Int32 = 0;
    while index < ArraySize(anchors) {
      if (StrLen(targetLocKey) > 0 && Equals(anchors[index].locKey, targetLocKey)) || Equals(anchors[index].displayName, targetName) { return index; };
      index += 1;
    };
    return -1;
  }

  // Map-planning coordinates, intentionally independent from physical terminal,
  // kerb, and traffic approach coordinates which will be surveyed later.
  private func GetStops() -> array<NCTCStopDefinition> {
    let stops: array<NCTCStopDefinition>;

    // 17 — Old Downtown → Upper Marina → Upper Eastside → Medical Center → Bank Block → Japantown → Little China → Studio City → Old Downtown
    ArrayPush(stops, this.Stop(-2127.0, 410.0, 57.0, "17", "Old Downtown"));
    ArrayPush(stops, this.Stop(-1753.0, 2445.0, 49.0, "17", "Upper Marina"));
    ArrayPush(stops, this.Stop(-1173.0, 1080.0, 108.0, "17", "Upper Eastside"));
    ArrayPush(stops, this.Stop(-1928.0, 1090.0, 41.0, "17", "Medical Center"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "17", "Bank Block"));
    ArrayPush(stops, this.Stop(-499.0, 594.0, 31.0, "17", "Japantown"));
    ArrayPush(stops, this.Stop(-1604.0, 1570.0, 72.0, "17", "Little China"));
    ArrayPush(stops, this.Stop(-555.0, 430.0, 68.0, "17", "Studio City"));
    ArrayPush(stops, this.Stop(-2127.0, 410.0, 57.0, "17", "Old Downtown"));

    // 22 — City Center → Bank Block → Corporate Center → Medical Center → Old Downtown → New Harbor → East Marina → Upper Marina → Upper Eastside → City Center
    ArrayPush(stops, this.Stop(-1942.0, -103.0, 7.0, "22", "City Center"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "22", "Bank Block"));
    ArrayPush(stops, this.Stop(-2242.0, 14.0, 82.0, "22", "Corporate Center"));
    ArrayPush(stops, this.Stop(-1928.0, 1090.0, 41.0, "22", "Medical Center"));
    ArrayPush(stops, this.Stop(-2127.0, 410.0, 57.0, "22", "Old Downtown"));
    ArrayPush(stops, this.Stop(-2143.0, 463.0, 9.0, "22", "New Harbor"));
    // East Marina and Upper Marina resolve to the same 2077 terminal.
    // Keep one physical stop so the line does not show Marina Gold Beach twice.
    ArrayPush(stops, this.Stop(-1359.0, 1710.0, 75.0, "22", "East Marina"));
    ArrayPush(stops, this.Stop(-1173.0, 1080.0, 108.0, "22", "Upper Eastside"));
    ArrayPush(stops, this.Stop(-1942.0, -103.0, 7.0, "22", "City Center"));

    // 23 — Corporate Center → Japantown → Little China → Studio City → Charter Hill → New Harbor → Old Downtown → Medical Center → Bank Block → Corporate Center
    ArrayPush(stops, this.Stop(-2242.0, 14.0, 82.0, "23", "Corporate Center"));
    ArrayPush(stops, this.Stop(-499.0, 594.0, 31.0, "23", "Japantown"));
    ArrayPush(stops, this.Stop(-1604.0, 1570.0, 72.0, "23", "Little China"));
    ArrayPush(stops, this.Stop(-555.0, 430.0, 68.0, "23", "Studio City"));
    ArrayPush(stops, this.Stop(-1152.0, -420.0, 53.0, "23", "Charter Hill"));
    ArrayPush(stops, this.Stop(-2143.0, 463.0, 9.0, "23", "New Harbor"));
    ArrayPush(stops, this.Stop(-2127.0, 410.0, 57.0, "23", "Old Downtown"));
    ArrayPush(stops, this.Stop(-1928.0, 1090.0, 41.0, "23", "Medical Center"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "23", "Bank Block"));
    ArrayPush(stops, this.Stop(-2242.0, 14.0, 82.0, "23", "Corporate Center"));

    // 51 — South Night City → Studio City → Little China → Japantown → University District → South Night City
    ArrayPush(stops, this.Stop(-2405.0, -694.0, 58.0, "51", "South Night City"));
    ArrayPush(stops, this.Stop(-555.0, 430.0, 68.0, "51", "Studio City"));
    ArrayPush(stops, this.Stop(-1604.0, 1570.0, 72.0, "51", "Little China"));
    ArrayPush(stops, this.Stop(-499.0, 594.0, 31.0, "51", "Japantown"));
    ArrayPush(stops, this.Stop(-741.0, -475.0, 36.0, "51", "University District"));
    ArrayPush(stops, this.Stop(-2405.0, -694.0, 58.0, "51", "South Night City"));

    // 68 — City Center → Bank Block → Corporate Center → West Hill → University District → Japantown → Little China → Medical Center → Bank Block → Upper Eastside → City Center
    ArrayPush(stops, this.Stop(-1942.0, -103.0, 7.0, "68", "City Center"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "68", "Bank Block"));
    ArrayPush(stops, this.Stop(-2242.0, 14.0, 82.0, "68", "Corporate Center"));
    ArrayPush(stops, this.Stop(-161.0, 140.0, 130.0, "68", "West Hill"));
    ArrayPush(stops, this.Stop(-741.0, -475.0, 36.0, "68", "University District"));
    ArrayPush(stops, this.Stop(-499.0, 594.0, 31.0, "68", "Japantown"));
    ArrayPush(stops, this.Stop(-1604.0, 1570.0, 72.0, "68", "Little China"));
    ArrayPush(stops, this.Stop(-1928.0, 1090.0, 41.0, "68", "Medical Center"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "68", "Bank Block"));
    ArrayPush(stops, this.Stop(-1173.0, 1080.0, 108.0, "68", "Upper Eastside"));
    ArrayPush(stops, this.Stop(-1942.0, -103.0, 7.0, "68", "City Center"));

    // 72 — South Night City → University District → West Hill → Little Italy → Northside → Bank Block → City Center → Medical Center → Upper Eastside → Upper Marina → South Night City
    ArrayPush(stops, this.Stop(-2405.0, -694.0, 58.0, "72", "South Night City"));
    ArrayPush(stops, this.Stop(-741.0, -475.0, 36.0, "72", "University District"));
    ArrayPush(stops, this.Stop(-161.0, 140.0, 130.0, "72", "West Hill"));
    ArrayPush(stops, this.Stop(-555.0, 430.0, 68.0, "72", "Little Italy"));
    ArrayPush(stops, this.Stop(-1753.0, 2445.0, 49.0, "72", "Northside"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "72", "Bank Block"));
    ArrayPush(stops, this.Stop(-1942.0, -103.0, 7.0, "72", "City Center"));
    ArrayPush(stops, this.Stop(-1928.0, 1090.0, 41.0, "72", "Medical Center"));
    ArrayPush(stops, this.Stop(-1173.0, 1080.0, 108.0, "72", "Upper Eastside"));
    ArrayPush(stops, this.Stop(-1753.0, 2445.0, 49.0, "72", "Upper Marina"));
    ArrayPush(stops, this.Stop(-2405.0, -694.0, 58.0, "72", "South Night City"));
    return stops;
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
    let counts: array<Int32>;
    let position: Vector4;
    let service: String;
    let stopIndex: Int32 = 0;
    let index: Int32 = 0;
    let found: Int32;
    let anchorIndex: Int32;

    this.UnregisterAllMarkers();
    system = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(system) { return; };
    stops = this.GetStops();
    anchors = this.GetTravelAnchors(system);
    while stopIndex < ArraySize(stops) {
      anchorIndex = this.ResolveAnchor(stops[stopIndex], anchors);
      if anchorIndex >= 0 {
        position = anchors[anchorIndex].position;
        service = "NCTC " + stops[stopIndex].line + " — " + this.DisplayStopName(stops[stopIndex].stop);
        found = -1;
        index = 0;
        while index < ArraySize(positions) {
          if Vector4.Distance2D(positions[index], position) < 1.00 { found = index; break; };
          index += 1;
        };
        if found < 0 {
          ArrayPush(positions, position);
          ArrayPush(services, service);
          ArrayPush(lines, stops[stopIndex].line);
          ArrayPush(counts, 1);
        } else if !StrContains(services[found], service) {
          services[found] += "\n" + service;
          counts[found] += 1;
        };
      };
      stopIndex += 1;
    };
    index = 0;
    while index < ArraySize(positions) {
      markerData = new NCTCStopMappinData();
      markerData.line = lines[index];
      markerData.stop = "Transit Hub";
      markerData.services = services[index];
      markerData.isHub = counts[index] > 1;
      if markerData.isHub { markerData.line = "HUB"; };
      data.mappinType = t"Mappins.NCTCStopMappinDefinition";
      data.variant = gamedataMappinVariant.CPO_PingDoorVariant;
      data.active = true;
      data.scriptData = markerData;
      ArrayPush(this.m_registeredMappins, system.RegisterMappin(data, positions[index]));
      index += 1;
    };
  }

  public func UnregisterAllMarkers() -> Void {
    let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
    if IsDefined(system) {
      for id in this.m_registeredMappins { system.UnregisterMappin(id); };
    };
    ArrayClear(this.m_registeredMappins);
  }
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  let system: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGame());
  if IsDefined(system) { system.RegisterAllMarkers(); };
  return result;
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
  let system: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGame());
  if IsDefined(system) { system.UnregisterAllMarkers(); };
  return wrappedMethod();
}

// Native fast-travel and NCART mappins exist only after the world map opens.
// Registering here gives the exact-anchor table access to them.
@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
  let result: Bool = wrappedMethod();
  let player: wref<GameObject> = this.GetPlayerControlledObject();
  let system: ref<NCTCMapMarkerSystem>;
  if IsDefined(player) {
    system = NCTCMapMarkerSystem.GetInstance(player.GetGame());
    if IsDefined(system) { system.RegisterAllMarkers(); };
  };
  return result;
}

@addMethod(BaseMappinBaseController)
protected final func ApplyNCTCStopIcon(line: String) -> Void {
  let icon: wref<inkImage>;
  let color: CName = n"MainColors.Green";
  let useCustomOrange: Bool = false;
  let useCustomPink: Bool = false;
  let useCustomHub: Bool = false;

  // Colours identify a route while all stops remain under the one NCTC map
  // filter.  No vanilla filter category is repurposed for individual lines.
  switch line {
    case "17": useCustomOrange = true; break;
    case "22": color = n"MainColors.Yellow"; break;
    case "23": useCustomPink = true; break;
    case "51": color = n"MainColors.Green"; break;
    case "68": color = n"MainColors.Purple"; break;
    case "72": color = n"MainColors.Blue"; break;
    case "HUB": useCustomHub = true; break;
  };

  inkImageRef.SetAtlasResource(this.iconWidget, r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
  inkImageRef.SetTexturePart(this.iconWidget, n"fast_travel");
  // CPO_PingDoor binds yellow by default. NCTC owns the marker, so replace
  // that vanilla binding with the colour of its transit line.
  icon = inkImageRef.Get(this.iconWidget) as inkImage;
  if IsDefined(icon) {
    icon.UnbindProperty(n"tintColor");
    if useCustomOrange {
      icon.SetTintColor(new HDRColor(1.28, 0.32, 0.00, 1.00));
    } else if useCustomPink {
      icon.SetTintColor(new HDRColor(1.00, 0.25, 0.65, 1.00));
    } else if useCustomHub {
      icon.SetTintColor(new HDRColor(0.37, 0.96, 1.00, 1.00));
    } else {
      icon.BindProperty(n"tintColor", color);
    };
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
  wrappedMethod(data, menu);
  if !IsDefined(Deref(data).mappin) { return; };
  stopData = Deref(data).mappin.GetScriptData() as NCTCStopMappinData;
  if IsDefined(stopData) {
    if stopData.isHub {
      inkTextRef.SetText(this.m_titleText, "NCTC Transit Hub");
    } else {
      inkTextRef.SetText(this.m_titleText, stopData.services);
    };
    inkTextRef.SetText(this.m_descText, stopData.services);
  };
}
