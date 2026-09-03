module NCTC

public struct NCTCStopDefinition {
  public let position: Vector4;
  public let line: String;
  public let stop: String;
}

public class NCTCStopMappinData extends MappinScriptData {
  public let line: String;
  public let stop: String;
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
    ArrayPush(stops, this.Stop(-1359.0, 1710.0, 75.0, "22", "East Marina"));
    ArrayPush(stops, this.Stop(-1753.0, 2445.0, 49.0, "22", "Upper Marina"));
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
    let index: Int32 = 0;

    this.UnregisterAllMarkers();
    system = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(system) { return; };
    stops = this.GetStops();
    while index < ArraySize(stops) {
      markerData = new NCTCStopMappinData();
      markerData.line = stops[index].line;
      markerData.stop = stops[index].stop;
      data.mappinType = t"Mappins.NCTCStopMappinDefinition";
      data.variant = gamedataMappinVariant.CPO_PingDoorVariant;
      data.active = true;
      data.scriptData = markerData;
      ArrayPush(this.m_registeredMappins, system.RegisterMappin(data, stops[index].position));
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

@addMethod(BaseMappinBaseController)
protected final func ApplyNCTCStopIcon(line: String) -> Void {
  let icon: wref<inkImage>;
  let color: CName = n"MainColors.Green";
  let useCustomOrange: Bool = false;
  let useCustomPink: Bool = false;

  // Colours identify a route while all stops remain under the one NCTC map
  // filter.  No vanilla filter category is repurposed for individual lines.
  switch line {
    case "17": useCustomOrange = true; break;
    case "22": color = n"MainColors.Yellow"; break;
    case "23": useCustomPink = true; break;
    case "51": color = n"MainColors.Green"; break;
    case "68": color = n"MainColors.Purple"; break;
    case "72": color = n"MainColors.Blue"; break;
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
    inkTextRef.SetText(this.m_titleText, "NCTC " + stopData.line + " — " + stopData.stop);
    inkTextRef.SetText(this.m_descText, "Map-planning candidate. Physical terminal location to be surveyed.");
  };
}
