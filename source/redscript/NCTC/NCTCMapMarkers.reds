module NCTC

public struct NCTCStopDefinition {
  public let position: Vector4;
  public let line: String;
  public let stop: String;
}

public class NCTCStopMappinData extends MappinScriptData {
  public let lines: array<String>;
  public let stops: array<String>;
  public let isHub: Bool;
}

public class NCTCHubDefinition extends IScriptable {
  public let position: Vector4;
  public let lines: array<String>;
  public let stops: array<String>;

  public func AddService(line: String, stop: String) -> Void {
    ArrayPush(this.lines, line);
    ArrayPush(this.stops, stop);
  }

  public func IsHub() -> Bool {
    return ArraySize(this.lines) > 1;
  }
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
  public func GetStops() -> array<NCTCStopDefinition> {
    let stops: array<NCTCStopDefinition>;

    // 17 — Central Loop
    ArrayPush(stops, this.Stop(-2127.0, 410.0, 57.0, "17", "Downtown West"));
    ArrayPush(stops, this.Stop(-1883.0, 659.0, 64.0, "17", "Downtown North"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "17", "Corpo Plaza North"));
    ArrayPush(stops, this.Stop(-1604.0, 1570.0, 72.0, "17", "Little China"));
    ArrayPush(stops, this.Stop(-1173.0, 1080.0, 108.0, "17", "Kabuki South"));
    ArrayPush(stops, this.Stop(-496.0, 956.0, 74.0, "17", "Japantown East"));
    ArrayPush(stops, this.Stop(-670.0, 877.0, 20.0, "17", "Jig-Jig Street"));
    ArrayPush(stops, this.Stop(-161.0, 140.0, 130.0, "17", "Charter Hill"));

    // 22 — Waterfront
    ArrayPush(stops, this.Stop(-2127.0, 410.0, 57.0, "22", "Downtown"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "22", "Corpo Plaza North"));
    ArrayPush(stops, this.Stop(-1928.0, 1090.0, 41.0, "22", "Med Center / Little China"));
    ArrayPush(stops, this.Stop(-2242.0, 14.0, 82.0, "22", "Arasaka Waterfront South"));
    ArrayPush(stops, this.Stop(-2143.0, 463.0, 9.0, "22", "Arasaka Waterfront North"));
    ArrayPush(stops, this.Stop(-1753.0, 2445.0, 49.0, "22", "Northside Industrial"));
    ArrayPush(stops, this.Stop(-1359.0, 1710.0, 75.0, "22", "Kabuki Waterfront"));
    ArrayPush(stops, this.Stop(-1604.0, 1570.0, 72.0, "22", "Little China"));

    // 23 — Corpo–Westbrook
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "23", "Corpo Plaza"));
    ArrayPush(stops, this.Stop(-1883.0, 659.0, 64.0, "23", "Downtown East"));
    ArrayPush(stops, this.Stop(-1928.0, 1090.0, 41.0, "23", "Little China West"));
    ArrayPush(stops, this.Stop(-555.0, 430.0, 68.0, "23", "Japantown South"));
    ArrayPush(stops, this.Stop(-499.0, 594.0, 31.0, "23", "Japantown Central"));
    ArrayPush(stops, this.Stop(-1152.0, -420.0, 53.0, "23", "Charter Hill South"));
    ArrayPush(stops, this.Stop(-290.0, 547.0, 82.0, "23", "Charter Hill North"));
    ArrayPush(stops, this.Stop(437.0, 110.0, 92.0, "23", "North Oak Entrance"));

    // 51 — South Connector
    ArrayPush(stops, this.Stop(-2456.0, -734.0, 67.0, "51", "Wellsprings West"));
    ArrayPush(stops, this.Stop(-2190.0, -1012.0, 51.0, "51", "Wellsprings East"));
    ArrayPush(stops, this.Stop(-1452.0, -1022.0, 101.0, "51", "The Glen South"));
    ArrayPush(stops, this.Stop(-1614.0, -1325.0, 94.0, "51", "The Glen North"));
    ArrayPush(stops, this.Stop(-942.0, -355.0, 31.0, "51", "Vista del Rey"));
    ArrayPush(stops, this.Stop(-1604.0, 1570.0, 72.0, "51", "Little China"));
    ArrayPush(stops, this.Stop(-499.0, 594.0, 31.0, "51", "Japantown"));
    ArrayPush(stops, this.Stop(-1152.0, -420.0, 53.0, "51", "Charter Hill South"));

    // 68 — Central Local
    ArrayPush(stops, this.Stop(-1942.0, -103.0, 7.0, "68", "Downtown Central"));
    ArrayPush(stops, this.Stop(-2272.0, 155.0, 127.0, "68", "Corpo Plaza West"));
    ArrayPush(stops, this.Stop(-1152.0, -420.0, 53.0, "68", "Charter Hill South"));
    ArrayPush(stops, this.Stop(-161.0, 140.0, 130.0, "68", "Charter Hill Central"));
    ArrayPush(stops, this.Stop(-555.0, 430.0, 68.0, "68", "Japantown West"));
    ArrayPush(stops, this.Stop(-499.0, 594.0, 31.0, "68", "Japantown Central"));
    ArrayPush(stops, this.Stop(-1928.0, 1090.0, 41.0, "68", "Little China West"));
    ArrayPush(stops, this.Stop(-1374.0, 1327.0, 59.0, "68", "Med Center"));
    ArrayPush(stops, this.Stop(-1173.0, 1080.0, 108.0, "68", "Kabuki South"));

    // 72 — Crosstown
    ArrayPush(stops, this.Stop(-2405.0, -694.0, 58.0, "72", "Wellsprings"));
    ArrayPush(stops, this.Stop(-1452.0, -1022.0, 101.0, "72", "The Glen"));
    ArrayPush(stops, this.Stop(-741.0, -475.0, 36.0, "72", "Vista del Rey"));
    ArrayPush(stops, this.Stop(-2127.0, 410.0, 57.0, "72", "Downtown West"));
    ArrayPush(stops, this.Stop(-161.0, 140.0, 130.0, "72", "Charter Hill"));
    ArrayPush(stops, this.Stop(-496.0, 956.0, 74.0, "72", "Japantown North"));
    ArrayPush(stops, this.Stop(-1753.0, 2445.0, 49.0, "72", "Northside"));
    ArrayPush(stops, this.Stop(-839.0, 1828.0, 36.0, "72", "Kabuki"));
    ArrayPush(stops, this.Stop(-1497.0, 1529.0, 18.0, "72", "Little China / Med Center"));
    ArrayPush(stops, this.Stop(-1883.0, 659.0, 64.0, "72", "Downtown East"));
    return stops;
  }

  private func GetHubs() -> array<ref<NCTCHubDefinition>> {
    let hubs: array<ref<NCTCHubDefinition>>;
    let stops: array<NCTCStopDefinition> = this.GetStops();
    let hub: ref<NCTCHubDefinition>;
    let index: Int32 = 0;
    let hubIndex: Int32 = 0;
    let found: Bool;

    while index < ArraySize(stops) {
      found = false;
      hubIndex = 0;
      while hubIndex < ArraySize(hubs) {
        if Vector4.Distance(hubs[hubIndex].position, stops[index].position) < 0.10 {
          hubs[hubIndex].AddService(stops[index].line, stops[index].stop);
          found = true;
          break;
        };
        hubIndex += 1;
      };
      if !found {
        hub = new NCTCHubDefinition();
        hub.position = stops[index].position;
        hub.AddService(stops[index].line, stops[index].stop);
        ArrayPush(hubs, hub);
      };
      index += 1;
    };
    return hubs;
  }

  public func RegisterAllMarkers() -> Void {
    let data: MappinData;
    let markerData: ref<NCTCStopMappinData>;
    let system: ref<MappinSystem>;
    let hubs: array<ref<NCTCHubDefinition>>;
    let index: Int32 = 0;

    this.UnregisterAllMarkers();
    system = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(system) { return; };
    hubs = this.GetHubs();
    while index < ArraySize(hubs) {
      markerData = new NCTCStopMappinData();
      markerData.lines = hubs[index].lines;
      markerData.stops = hubs[index].stops;
      markerData.isHub = hubs[index].IsHub();
      data.mappinType = t"Mappins.NCTCStopMappinDefinition";
      data.variant = gamedataMappinVariant.CPO_PingDoorVariant;
      data.active = true;
      data.scriptData = markerData;
      ArrayPush(this.m_registeredMappins, system.RegisterMappin(data, hubs[index].position));
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
protected final func ApplyNCTCStopIcon(data: ref<NCTCStopMappinData>) -> Void {
  let icon: wref<inkImage>;
  let color: CName = n"MainColors.Green";
  let useCustomOrange: Bool = false;

  // Colours identify a route while all stops remain under the one NCTC map
  // filter.  No vanilla filter category is repurposed for individual lines.
  if data.isHub {
    color = n"MainColors.White";
  } else {
    switch data.lines[0] {
      case "17": color = n"MainColors.Green"; break;
      case "22": color = n"MainColors.Blue"; break;
      case "23": color = n"MainColors.Yellow"; break;
      case "51": color = n"MainColors.Red"; break;
      case "68": color = n"MainColors.Purple"; break;
      case "72": useCustomOrange = true; break;
    };
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
    } else {
      icon.BindProperty(n"tintColor", color);
    };
  };
}

@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  let data: ref<NCTCStopMappinData> = this.GetMappin().GetScriptData() as NCTCStopMappinData;
  if IsDefined(data) { this.ApplyNCTCStopIcon(data); };
}

@wrapMethod(WorldMapTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
  let stopData: ref<NCTCStopMappinData>;
  wrappedMethod(data, menu);
  if !IsDefined(Deref(data).mappin) { return; };
  stopData = Deref(data).mappin.GetScriptData() as NCTCStopMappinData;
  if IsDefined(stopData) {
    if stopData.isHub {
      inkTextRef.SetText(this.m_titleText, "NCTC Hub");
      inkTextRef.SetText(this.m_descText, NCTCFormatServices(stopData));
    } else {
      inkTextRef.SetText(this.m_titleText, "NCTC " + stopData.lines[0] + " — " + stopData.stops[0]);
      inkTextRef.SetText(this.m_descText, "Map-planning candidate. Physical terminal location to be surveyed.");
    };
  };
}

public func NCTCFormatServices(data: ref<NCTCStopMappinData>) -> String {
  let result: String = "Correspondance";
  let index: Int32 = 0;
  while index < ArraySize(data.lines) {
    result += "\nLigne " + data.lines[index] + " — " + data.stops[index];
    index += 1;
  };
  return result;
}
