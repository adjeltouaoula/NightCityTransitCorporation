module NCTC

@if(ModuleExists("ModSettingsModule"))
import ModSettingsModule.*

public enum NCTCSurveyLine {
  Line17 = 0,
  Line22 = 1,
  Line23 = 2,
  Line51 = 3,
  Line68 = 4,
  Line72 = 5
}

public class NCTCSurveyWriteConfirmationCallback extends DelayCallback {
  public let game: GameInstance;
  public let eventId: Int32;
  public let kind: String;

  public func Call() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.game);
    if IsDefined(quests) && Equals(quests.GetFact(n"nctc_survey_write_ack_event_id"), this.eventId) {
      NCTCSettings.Notify(this.game, "NCTC survey confirmed: " + this.kind);
    } else {
      NCTCSettings.Notify(this.game, "NCTC survey not confirmed: " + this.kind);
    };
  }
}

// CET writes survey coordinates directly to disk in the experimental devkit.
// This small fact channel is notification-only: it never carries positions or
// persists any survey data through a save.
public class NCTCDirectSurveyNoticeCallback extends DelayCallback {
  public let game: GameInstance;
  public let lastNoticeId: Int32;

  public func Configure(game: GameInstance, lastNoticeId: Int32) -> Void {
    this.game = game; this.lastNoticeId = lastNoticeId;
  }

  public func Call() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.game);
    let noticeId: Int32;
    let point: Int32;
    let next: ref<NCTCDirectSurveyNoticeCallback>;
    if IsDefined(quests) {
      noticeId = quests.GetFact(n"nctc_survey_direct_notice_id");
      if noticeId > this.lastNoticeId {
        point = quests.GetFact(n"nctc_survey_direct_notice_point");
        NCTCSettings.Notify(this.game, "NCTC survey confirmed: " + (Equals(point, 1) ? "spawn" : Equals(point, 2) ? "approach" : Equals(point, 4) ? "Bay Point 2" : "Bay Point 1"));
        this.lastNoticeId = noticeId;
      } else if noticeId < this.lastNoticeId {
        this.lastNoticeId = noticeId;
      };
    };
    next = new NCTCDirectSurveyNoticeCallback();
    next.Configure(this.game, this.lastNoticeId);
    GameInstance.GetDelaySystem(this.game).DelayCallback(next, 0.25, false);
  }
}

public class NCTCSurveySelectionPublishCallback extends DelayCallback {
  public let game: GameInstance;

  public func Configure(game: GameInstance) -> Void { this.game = game; }

  public func Call() -> Void {
    let settings: ref<NCTCSettings> = NCTCSettings.Get(this.game);
    let next: ref<NCTCSurveySelectionPublishCallback> = new NCTCSurveySelectionPublishCallback();
    if IsDefined(settings) { settings.PublishSurveySettings(); };
    next.Configure(this.game);
    GameInstance.GetDelaySystem(this.game).DelayCallback(next, 1.00, false);
  }
}

public enum NCTCSurveyPassage {
  L17_SkylineEst_QGDelamain_PetrelStreet = 0,
  L17_QGDelamain_PetrelStreet_Rocade = 1,
  L17_PetrelStreet_Rocade_CongressMadison = 2,
  L17_Rocade_CongressMadison_CollegeStreet = 3,
  L17_CongressMadison_CollegeStreet_SkylineEst = 4,
  L17_CollegeStreet_SkylineEst_QGDelamain = 5,
  L22_Rocade_SarsatiRepublic_Rocade = 6,
  L22_SarsatiRepublic_Rocade_MemorialPark = 7,
  L22_Rocade_MemorialPark_Rocade = 8,
  L22_MemorialPark_Rocade_QGDelamain = 9,
  L22_Rocade_QGDelamain_PetrelStreet = 10,
  L22_QGDelamain_PetrelStreet_Rocade = 11,
  L22_PetrelStreet_Rocade_SarsatiRepublic = 12,
  L23_Rocade_MemorialPark_CongressMadison = 13,
  L23_MemorialPark_CongressMadison_CollegeStreet = 14,
  L23_CongressMadison_CollegeStreet_SkylineEst = 15,
  L23_CollegeStreet_SkylineEst_RepublicVine = 16,
  L23_SkylineEst_RepublicVine_PetrelStreet = 17,
  L23_RepublicVine_PetrelStreet_QGDelamain = 18,
  L23_PetrelStreet_QGDelamain_Rocade = 19,
  L23_QGDelamain_Rocade_MemorialPark = 20,
  L51_SenateMarket_Wellsprings_SkylineEst = 21,
  L51_Wellsprings_SkylineEst_CollegeStreet = 22,
  L51_SkylineEst_CollegeStreet_CongressMadison = 23,
  L51_CollegeStreet_CongressMadison_SenateMarket = 24,
  L51_CongressMadison_SenateMarket_Wellsprings = 25,
  L68_Rocade_SarsatiRepublic_Rocade = 26,
  L68_SarsatiRepublic_Rocade_MemorialPark = 27,
  L68_Rocade_MemorialPark_CanneryPlaza = 28,
  L68_MemorialPark_CanneryPlaza_SenateMarket = 29,
  L68_CanneryPlaza_SenateMarket_CongressMadison = 30,
  L68_SenateMarket_CongressMadison_CollegeStreet = 31,
  L68_CongressMadison_CollegeStreet_Rocade = 32,
  L68_CollegeStreet_Rocade_SarsatiRepublic = 33,
  L72_PetrelStreet_Wellsprings_SenateMarket = 34,
  L72_Wellsprings_SenateMarket_CanneryPlaza = 35,
  L72_SenateMarket_CanneryPlaza_MarinadeGoldBeach = 36,
  L72_CanneryPlaza_MarinadeGoldBeach_AlexanderStreet = 37,
  L72_MarinadeGoldBeach_AlexanderStreet_Rocade = 38,
  L72_AlexanderStreet_Rocade_SarsatiRepublic = 39,
  L72_Rocade_SarsatiRepublic_Rocade = 40,
  L72_SarsatiRepublic_Rocade_PetrelStreet = 41,
  L72_Rocade_PetrelStreet_Wellsprings = 42,
}

public enum NCTCDeveloperTerminalAction {
  CallBus = 0,
  RecordStop = 1
}

public enum NCTCDraftLineColor {
  Orange = 0,
  Yellow = 1,
  Pink = 2,
  Green = 3,
  Violet = 4,
  Blue = 5,
  Red = 6
}

// Saved by Mod Settings, not by a CET overlay.
public class NCTCSettings extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Adaptive traffic speed")
  @runtimeProperty("ModSettings.description", "Automatically adapts the service-bus traffic speed by district and by long road segments.")
  @runtimeProperty("ModSettings.category", "Service bus")
  @runtimeProperty("ModSettings.category.order", "-10")
  public let adaptiveTrafficSpeed: Bool = true;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Dense city speed")
  @runtimeProperty("ModSettings.description", "Base traffic-speed target for City Center / Dogtown before the long-road bonus.")
  @runtimeProperty("ModSettings.category", "Service bus")
  @runtimeProperty("ModSettings.min", "25")
  @runtimeProperty("ModSettings.max", "80")
  @runtimeProperty("ModSettings.step", "5")
  @runtimeProperty("ModSettings.dependency", "adaptiveTrafficSpeed")
  public let denseCityTrafficSpeed: Int32 = 45;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "City speed")
  @runtimeProperty("ModSettings.description", "Base traffic-speed target for Watson, Westbrook and Heywood.")
  @runtimeProperty("ModSettings.category", "Service bus")
  @runtimeProperty("ModSettings.min", "25")
  @runtimeProperty("ModSettings.max", "80")
  @runtimeProperty("ModSettings.step", "5")
  @runtimeProperty("ModSettings.dependency", "adaptiveTrafficSpeed")
  public let cityTrafficSpeed: Int32 = 50;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Outer city speed")
  @runtimeProperty("ModSettings.description", "Base traffic-speed target for Santo Domingo and Pacifica.")
  @runtimeProperty("ModSettings.category", "Service bus")
  @runtimeProperty("ModSettings.min", "25")
  @runtimeProperty("ModSettings.max", "90")
  @runtimeProperty("ModSettings.step", "5")
  @runtimeProperty("ModSettings.dependency", "adaptiveTrafficSpeed")
  public let outerCityTrafficSpeed: Int32 = 55;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Badlands speed")
  @runtimeProperty("ModSettings.description", "Base traffic-speed target in the Badlands.")
  @runtimeProperty("ModSettings.category", "Service bus")
  @runtimeProperty("ModSettings.min", "30")
  @runtimeProperty("ModSettings.max", "100")
  @runtimeProperty("ModSettings.step", "5")
  @runtimeProperty("ModSettings.dependency", "adaptiveTrafficSpeed")
  public let badlandsTrafficSpeed: Int32 = 70;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Fallback / manual speed")
  @runtimeProperty("ModSettings.description", "Fallback when no district profile is resolved. Also used as the fixed speed when adaptive mode is disabled.")
  @runtimeProperty("ModSettings.category", "Service bus")
  @runtimeProperty("ModSettings.min", "25")
  @runtimeProperty("ModSettings.max", "90")
  @runtimeProperty("ModSettings.step", "5")
  public let fallbackTrafficSpeed: Int32 = 50;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Absolute speed ceiling")
  @runtimeProperty("ModSettings.description", "Hard safety ceiling applied after district and long-road bonuses.")
  @runtimeProperty("ModSettings.category", "Service bus")
  @runtimeProperty("ModSettings.min", "30")
  @runtimeProperty("ModSettings.max", "120")
  @runtimeProperty("ModSettings.step", "5")
  public let absoluteTrafficSpeedCeiling: Int32 = 80;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Developer mode")
  @runtimeProperty("ModSettings.description", "Enables NCTC survey captures. Numpad 1 records spawn, 2 approach, and 3 berth.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.category.order", "0")
  public let developerMode: Bool = false;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Show metro / fast travel LocKeys")
  @runtimeProperty("ModSettings.description", "On the world map, adds the LocKey identifier to vanilla metro and fast-travel tooltips. Developer mode only.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let showTravelAnchorLocKeys: Bool = false;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Show passage points")
  @runtimeProperty("ModSettings.description", "Shows invisible traffic-only passage points on the map. Developer mode only; they never appear in the public mod.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let showPassagePoints: Bool = false;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Developer terminal action")
  @runtimeProperty("ModSettings.description", "Choose whether F at a terminal calls the bus or records that terminal as the next draft stop.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.displayValues.CallBus", "Call bus")
  @runtimeProperty("ModSettings.displayValues.RecordStop", "Record new stop")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let developerTerminalAction: NCTCDeveloperTerminalAction = NCTCDeveloperTerminalAction.CallBus;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Legacy survey line")
  @runtimeProperty("ModSettings.description", "Legacy fixed selector. Hidden; use Active line number.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.displayValues.Line17", "17")
  @runtimeProperty("ModSettings.displayValues.Line22", "22")
  @runtimeProperty("ModSettings.displayValues.Line23", "23")
  @runtimeProperty("ModSettings.displayValues.Line51", "51")
  @runtimeProperty("ModSettings.displayValues.Line68", "68")
  @runtimeProperty("ModSettings.displayValues.Line72", "72")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let surveyLine: NCTCSurveyLine = NCTCSurveyLine.Line17;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Active line number")
  @runtimeProperty("ModSettings.description", "Line currently edited. If it does not exist, adding its first stop creates it with New line color.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "999")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let activeLineNumber: Int32 = 17;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Previous existing line")
  @runtimeProperty("ModSettings.description", "Developer-only shortcut. Cycles the active line through lines present in the current network.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let previousExistingLineKey: EInputKey = EInputKey.IK_NumSlash;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Next existing line")
  @runtimeProperty("ModSettings.description", "Developer-only shortcut. Cycles the active line through lines present in the current network.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let nextExistingLineKey: EInputKey = EInputKey.IK_NumStar;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Previous survey stop")
  @runtimeProperty("ModSettings.description", "Developer-only shortcut. Selects the previous stop on the active line; wraps from the first stop to the last.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let previousSurveyStopKey: EInputKey = EInputKey.IK_NumMinus;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Next survey stop")
  @runtimeProperty("ModSettings.description", "Developer-only shortcut. Selects the next stop on the active line; wraps from the last stop to the first.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let nextSurveyStopKey: EInputKey = EInputKey.IK_NumPlus;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Survey stop")
  @runtimeProperty("ModSettings.description", "Position of the stop in the currently selected line. 1 is the first stop currently present in nctc_network.json; removed stops are skipped.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "50")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let surveyStopIndex: Int32 = 1;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Survey passage")
  @runtimeProperty("ModSettings.description", "Direction being recorded. More passages are added as each line is surveyed.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.displayValues.L17_SkylineEst_QGDelamain_PetrelStreet", "17 · QG Delamain · Skyline Est -> Petrel Street")
  @runtimeProperty("ModSettings.displayValues.L17_QGDelamain_PetrelStreet_Rocade", "17 · Petrel Street · QG Delamain -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L17_PetrelStreet_Rocade_CongressMadison", "17 · Rocade · Petrel Street -> Congress & Madison")
  @runtimeProperty("ModSettings.displayValues.L17_Rocade_CongressMadison_CollegeStreet", "17 · Congress & Madison · Rocade -> College Street")
  @runtimeProperty("ModSettings.displayValues.L17_CongressMadison_CollegeStreet_SkylineEst", "17 · College Street · Congress & Madison -> Skyline Est")
  @runtimeProperty("ModSettings.displayValues.L17_CollegeStreet_SkylineEst_QGDelamain", "17 · Skyline Est · College Street -> QG Delamain")
  @runtimeProperty("ModSettings.displayValues.L22_Rocade_SarsatiRepublic_Rocade", "22 · Sarsati & Republic · Rocade -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L22_SarsatiRepublic_Rocade_MemorialPark", "22 · Rocade · Sarsati & Republic -> Memorial Park")
  @runtimeProperty("ModSettings.displayValues.L22_Rocade_MemorialPark_Rocade", "22 · Memorial Park · Rocade -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L22_MemorialPark_Rocade_QGDelamain", "22 · Rocade · Memorial Park -> QG Delamain")
  @runtimeProperty("ModSettings.displayValues.L22_Rocade_QGDelamain_PetrelStreet", "22 · QG Delamain · Rocade -> Petrel Street")
  @runtimeProperty("ModSettings.displayValues.L22_QGDelamain_PetrelStreet_Rocade", "22 · Petrel Street · QG Delamain -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L22_PetrelStreet_Rocade_SarsatiRepublic", "22 · Rocade · Petrel Street -> Sarsati & Republic")
  @runtimeProperty("ModSettings.displayValues.L23_Rocade_MemorialPark_CongressMadison", "23 · Memorial Park · Rocade -> Congress & Madison")
  @runtimeProperty("ModSettings.displayValues.L23_MemorialPark_CongressMadison_CollegeStreet", "23 · Congress & Madison · Memorial Park -> College Street")
  @runtimeProperty("ModSettings.displayValues.L23_CongressMadison_CollegeStreet_SkylineEst", "23 · College Street · Congress & Madison -> Skyline Est")
  @runtimeProperty("ModSettings.displayValues.L23_CollegeStreet_SkylineEst_RepublicVine", "23 · Skyline Est · College Street -> Republic & Vine")
  @runtimeProperty("ModSettings.displayValues.L23_SkylineEst_RepublicVine_PetrelStreet", "23 · Republic & Vine · Skyline Est -> Petrel Street")
  @runtimeProperty("ModSettings.displayValues.L23_RepublicVine_PetrelStreet_QGDelamain", "23 · Petrel Street · Republic & Vine -> QG Delamain")
  @runtimeProperty("ModSettings.displayValues.L23_PetrelStreet_QGDelamain_Rocade", "23 · QG Delamain · Petrel Street -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L23_QGDelamain_Rocade_MemorialPark", "23 · Rocade · QG Delamain -> Memorial Park")
  @runtimeProperty("ModSettings.displayValues.L51_SenateMarket_Wellsprings_SkylineEst", "51 · Wellsprings · Senate & Market -> Skyline Est")
  @runtimeProperty("ModSettings.displayValues.L51_Wellsprings_SkylineEst_CollegeStreet", "51 · Skyline Est · Wellsprings -> College Street")
  @runtimeProperty("ModSettings.displayValues.L51_SkylineEst_CollegeStreet_CongressMadison", "51 · College Street · Skyline Est -> Congress & Madison")
  @runtimeProperty("ModSettings.displayValues.L51_CollegeStreet_CongressMadison_SenateMarket", "51 · Congress & Madison · College Street -> Senate & Market")
  @runtimeProperty("ModSettings.displayValues.L51_CongressMadison_SenateMarket_Wellsprings", "51 · Senate & Market · Congress & Madison -> Wellsprings")
  @runtimeProperty("ModSettings.displayValues.L68_Rocade_SarsatiRepublic_Rocade", "68 · Sarsati & Republic · Rocade -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L68_SarsatiRepublic_Rocade_MemorialPark", "68 · Rocade · Sarsati & Republic -> Memorial Park")
  @runtimeProperty("ModSettings.displayValues.L68_Rocade_MemorialPark_CanneryPlaza", "68 · Memorial Park · Rocade -> Cannery Plaza")
  @runtimeProperty("ModSettings.displayValues.L68_MemorialPark_CanneryPlaza_SenateMarket", "68 · Cannery Plaza · Memorial Park -> Senate & Market")
  @runtimeProperty("ModSettings.displayValues.L68_CanneryPlaza_SenateMarket_CongressMadison", "68 · Senate & Market · Cannery Plaza -> Congress & Madison")
  @runtimeProperty("ModSettings.displayValues.L68_SenateMarket_CongressMadison_CollegeStreet", "68 · Congress & Madison · Senate & Market -> College Street")
  @runtimeProperty("ModSettings.displayValues.L68_CongressMadison_CollegeStreet_Rocade", "68 · College Street · Congress & Madison -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L68_CollegeStreet_Rocade_SarsatiRepublic", "68 · Rocade · College Street -> Sarsati & Republic")
  @runtimeProperty("ModSettings.displayValues.L72_PetrelStreet_Wellsprings_SenateMarket", "72 · Wellsprings · Petrel Street -> Senate & Market")
  @runtimeProperty("ModSettings.displayValues.L72_Wellsprings_SenateMarket_CanneryPlaza", "72 · Senate & Market · Wellsprings -> Cannery Plaza")
  @runtimeProperty("ModSettings.displayValues.L72_SenateMarket_CanneryPlaza_MarinadeGoldBeach", "72 · Cannery Plaza · Senate & Market -> Marina de Gold Beach")
  @runtimeProperty("ModSettings.displayValues.L72_CanneryPlaza_MarinadeGoldBeach_AlexanderStreet", "72 · Marina de Gold Beach · Cannery Plaza -> Alexander Street")
  @runtimeProperty("ModSettings.displayValues.L72_MarinadeGoldBeach_AlexanderStreet_Rocade", "72 · Alexander Street · Marina de Gold Beach -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L72_AlexanderStreet_Rocade_SarsatiRepublic", "72 · Rocade · Alexander Street -> Sarsati & Republic")
  @runtimeProperty("ModSettings.displayValues.L72_Rocade_SarsatiRepublic_Rocade", "72 · Sarsati & Republic · Rocade -> Rocade")
  @runtimeProperty("ModSettings.displayValues.L72_SarsatiRepublic_Rocade_PetrelStreet", "72 · Rocade · Sarsati & Republic -> Petrel Street")
  @runtimeProperty("ModSettings.displayValues.L72_Rocade_PetrelStreet_Wellsprings", "72 · Petrel Street · Rocade -> Wellsprings")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let surveyPassage: NCTCSurveyPassage = NCTCSurveyPassage.L17_SkylineEst_QGDelamain_PetrelStreet;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Record spawn")
  @runtimeProperty("ModSettings.description", "Records the off-screen traffic-lane spawn position.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let recordSpawnKey: EInputKey = EInputKey.IK_NumPad1;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Record approach")
  @runtimeProperty("ModSettings.description", "Records the road approach position before the stop.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let recordApproachKey: EInputKey = EInputKey.IK_NumPad2;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Record berth")
  @runtimeProperty("ModSettings.description", "Records the exact bus stopping position.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let recordBerthKey: EInputKey = EInputKey.IK_NumPad3;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Edit Bay Point 2")
  @runtimeProperty("ModSettings.description", "OFF: NumPad 3 creates/updates Bay Point 1 (the existing berth). ON: NumPad 3 creates/updates Bay Point 2, the second end of a bus bay.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let editBayPoint2: Bool = false;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Remove Bay Point 2")
  @runtimeProperty("ModSettings.description", "One-shot action. Removes only Bay Point 2 from the selected stop, keeps Bay Point 1, then resets to OFF.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let removeBayPoint2: Bool = false;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Add manual stop")
  @runtimeProperty("ModSettings.description", "Adds a stop at V's current position. Use this for metro stations or roadside stops; nearby services are grouped into one hub.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let addManualStopKey: EInputKey = EInputKey.IK_NumPad4;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Delete selected stop")
  @runtimeProperty("ModSettings.description", "Deletes the stop selected above from the active line. Other lines at the same hub are kept.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let deleteNearestStopKey: EInputKey = EInputKey.IK_NumPad5;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Move selected stop")
  @runtimeProperty("ModSettings.description", "Moves the selected stop to V's exact position without changing its spawn, approach, or berth. A metro or fast-travel anchor within 100 m supplies only its name and LocKey.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let moveSelectedStopKey: EInputKey = EInputKey.IK_NumPad6;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Record passage point after selected stop")
  @runtimeProperty("ModSettings.description", "Adds an invisible traffic waypoint after the selected stop and before the following stop. It is not a map stop and has no spawn, approach, or berth.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let recordPassageAfterSelectedKey: EInputKey = EInputKey.IK_NumPad7;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Delete nearest passage point")
  @runtimeProperty("ModSettings.description", "Deletes the nearest passage point for the selected line within 30 metres.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let deleteNearestPassageKey: EInputKey = EInputKey.IK_NumPad8;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Despawn service bus")
  @runtimeProperty("ModSettings.description", "Immediately removes the active NCTC bus and clears its pending route request. A new bus can then be called right away.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let despawnServiceBusKey: EInputKey = EInputKey.IK_NumPad9;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "New line number (legacy)")
  @runtimeProperty("ModSettings.description", "Legacy draft setting. Hidden; use Active line number.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "999")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let draftLineNumber: Int32 = 100;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "New line color")
  @runtimeProperty("ModSettings.description", "Applied when Active line number receives its first stop. Later changes do not alter an existing line.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.displayValues.Orange", "Orange")
  @runtimeProperty("ModSettings.displayValues.Yellow", "Yellow")
  @runtimeProperty("ModSettings.displayValues.Pink", "Pink")
  @runtimeProperty("ModSettings.displayValues.Green", "Green")
  @runtimeProperty("ModSettings.displayValues.Violet", "Violet")
  @runtimeProperty("ModSettings.displayValues.Blue", "Blue")
  @runtimeProperty("ModSettings.displayValues.Red", "Red")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let draftLineColor: NCTCDraftLineColor = NCTCDraftLineColor.Orange;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Create / replace draft line (legacy)")
  @runtimeProperty("ModSettings.description", "Legacy draft switch. Hidden; adding the first stop now creates the active line automatically.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let beginDraftLine: Bool = false;

  private let lastBayPoint2EditMode: Bool;

  private func OnAttach() -> Void {
    let callback: ref<NCTCDirectSurveyNoticeCallback>;
    let selectionCallback: ref<NCTCSurveySelectionPublishCallback>;
    let quests: ref<QuestsSystem>;
    this.RegisterSettings();
    this.lastBayPoint2EditMode = this.editBayPoint2;
    this.PublishSurveySettings();
    this.UpdateDeveloperVisibility();
    NCTCMapMarkerSystem.GetInstance(this.GetGameInstance()).RegisterAllMarkers();
    GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnSurveyKeyInput");
    quests = GameInstance.GetQuestsSystem(this.GetGameInstance());
    callback = new NCTCDirectSurveyNoticeCallback();
    callback.Configure(this.GetGameInstance(), IsDefined(quests) ? quests.GetFact(n"nctc_survey_direct_notice_id") : 0);
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(callback, 0.25, false);
    selectionCallback = new NCTCSurveySelectionPublishCallback();
    selectionCallback.Configure(this.GetGameInstance());
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(selectionCallback, 1.00, false);
  }

  private func OnDetach() -> Void {
    GameInstance.GetCallbackSystem().UnregisterCallback(n"Input/Key", this, n"OnSurveyKeyInput");
    this.UnregisterSettings();
  }

  @if(ModuleExists("ModSettingsModule"))
  public func OnModSettingsChange() -> Void {
    if this.developerMode && NotEquals(this.editBayPoint2, this.lastBayPoint2EditMode) {
      this.lastBayPoint2EditMode = this.editBayPoint2;
      NCTCSettings.Notify(this.GetGameInstance(), this.editBayPoint2 ? "NCTC - Editing Bay Point 2" : "NCTC - Editing Bay Point 1");
    };
    if this.developerMode && this.removeBayPoint2 {
      this.removeBayPoint2 = false;
      this.RemoveSelectedBayPoint2();
    };
    this.PublishSurveySettings();
    this.UpdateDeveloperVisibility();
    if this.developerMode { this.NotifySelectedSurveyStop(); };
  }

  public func PublishSurveySettings() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_survey_developer_mode", this.developerMode ? 1 : 0);
    quests.SetFact(n"nctc_survey_line", this.activeLineNumber);
    quests.SetFact(n"nctc_survey_selected_line", this.GetSelectedLineNumber());
    quests.SetFact(n"nctc_survey_selected_stop_index", this.surveyStopIndex);
    quests.SetFact(n"nctc_survey_edit_bay_point2", this.editBayPoint2 ? 1 : 0);
    quests.SetFact(n"nctc_survey_passage", EnumInt(this.surveyPassage));
  }

  private func NotifySelectedSurveyStop() -> Void {
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
    let line: Int32 = this.GetSelectedLineNumber();
    if !IsDefined(markers) || line < 1 { return; };
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC survey: line " + ToString(line) + " · stop " + ToString(this.surveyStopIndex) + " · " + markers.GetSurveyStopName(line, this.surveyStopIndex) + " · editing " + (this.editBayPoint2 ? "Bay Point 2" : "Bay Point 1"));
  }

  @if(ModuleExists("ModSettingsModule"))
  private func UpdateDeveloperVisibility() -> Void {
    let variable: ref<ConfigVar>;
    // A single category prevents empty developer headings leaking into the
    // normal configuration screen. Only the master switch stays visible.
    for variable in ModSettings.GetVars(n"Night City Transit Corporation", n"Developer mode") {
      if Equals(variable.GetName(), n"surveyLine") || Equals(variable.GetName(), n"surveyPassage") || Equals(variable.GetName(), n"recordSpawnKey") || Equals(variable.GetName(), n"recordApproachKey") || Equals(variable.GetName(), n"recordBerthKey") || Equals(variable.GetName(), n"draftLineNumber") || Equals(variable.GetName(), n"beginDraftLine") { variable.SetVisible(false); }
      else if Equals(variable.GetName(), n"removeBayPoint2") { variable.SetVisible(this.developerMode && this.editBayPoint2); }
      else if !Equals(variable.GetName(), n"developerMode") { variable.SetVisible(this.developerMode); };
    };
  }
  @if(!ModuleExists("ModSettingsModule"))
  private func UpdateDeveloperVisibility() -> Void {}

  protected cb func OnSurveyKeyInput(event: ref<KeyInputEvent>) -> Void {
    if !this.developerMode || !Equals(event.GetAction(), EInputAction.IACT_Press) { return; };
    // Spawn / approach / berth are captured directly by CET in the devkit
    // branch. That prevents a save restore from replaying old coordinates.
    if Equals(event.GetKey(), this.previousExistingLineKey) { this.CycleExistingLine(false); return; };
    if Equals(event.GetKey(), this.nextExistingLineKey) { this.CycleExistingLine(true); return; };
    if Equals(event.GetKey(), this.previousSurveyStopKey) { this.CycleSurveyStop(false); return; };
    if Equals(event.GetKey(), this.nextSurveyStopKey) { this.CycleSurveyStop(true); return; };
    if Equals(event.GetKey(), this.addManualStopKey) { this.RecordManualStop(); return; };
    if Equals(event.GetKey(), this.deleteNearestStopKey) { this.DeleteNearestStop(); return; };
    if Equals(event.GetKey(), this.moveSelectedStopKey) { this.MoveSelectedStop(); return; };
    if Equals(event.GetKey(), this.recordPassageAfterSelectedKey) { this.RecordPassageAfterSelected(); return; };
    if Equals(event.GetKey(), this.deleteNearestPassageKey) { this.DeleteNearestPassage(); return; };
    if Equals(event.GetKey(), this.despawnServiceBusKey) {
      if NCTCTransitSystem.Get(this.GetGameInstance()).DespawnServiceBus() { NCTCSettings.Notify(this.GetGameInstance(), "NCTC service bus despawned"); };
    };
  }

  private func RemoveSelectedBayPoint2() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let eventId: Int32;
    let confirmation: ref<NCTCSurveyWriteConfirmationCallback>;
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_survey_capture_line", this.GetSelectedLineNumber());
    quests.SetFact(n"nctc_survey_capture_stop_index", this.surveyStopIndex);
    quests.SetFact(n"nctc_survey_event_session", quests.GetFact(n"nctc_survey_runtime_session"));
    quests.SetFact(n"nctc_survey_event_kind", 10);
    eventId = quests.GetFact(n"nctc_survey_event_id") + 1;
    quests.SetFact(n"nctc_survey_write_ack_event_id", -1);
    quests.SetFact(n"nctc_survey_event_id", eventId);
    confirmation = new NCTCSurveyWriteConfirmationCallback();
    confirmation.game = this.GetGameInstance();
    confirmation.eventId = eventId;
    confirmation.kind = "Bay Point 2 removal";
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(confirmation, 0.50, false);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC - Remove Bay Point 2 requested");
  }

  private func CycleExistingLine(forward: Bool) -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let count: Int32; let index: Int32; let line: Int32;
    let candidate: Int32 = 0; let fallback: Int32 = 0;
    if !IsDefined(quests) { return; };
    count = quests.GetFact(n"nctc_external_network_stop_count");
    while index < count {
      line = quests.GetFact(StringToName("nctc_external_stop_" + ToString(index) + "_line"));
      if line > 0 {
        if forward {
          if line > this.activeLineNumber && (candidate == 0 || line < candidate) { candidate = line; };
          if fallback == 0 || line < fallback { fallback = line; };
        } else {
          if line < this.activeLineNumber && line > candidate { candidate = line; };
          if fallback == 0 || line > fallback { fallback = line; };
        };
      };
      index += 1;
    };
    if candidate == 0 { candidate = fallback; };
    if candidate > 0 { this.activeLineNumber = candidate; this.surveyStopIndex = 1; this.PublishSurveySettings(); this.NotifySelectedSurveyStop(); };
  }


  private func CycleSurveyStop(forward: Bool) -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let count: Int32;
    let index: Int32;
    let lineStopCount: Int32;
    if !IsDefined(quests) { return; };
    count = quests.GetFact(n"nctc_external_network_stop_count");
    while index < count {
      if Equals(quests.GetFact(StringToName("nctc_external_stop_" + ToString(index) + "_line")), this.activeLineNumber) {
        lineStopCount += 1;
      };
      index += 1;
    };
    if lineStopCount < 1 {
      this.surveyStopIndex = 1;
      this.PublishSurveySettings();
      this.NotifySelectedSurveyStop();
      return;
    };
    if forward {
      this.surveyStopIndex += 1;
      if this.surveyStopIndex > lineStopCount { this.surveyStopIndex = 1; };
    } else {
      this.surveyStopIndex -= 1;
      if this.surveyStopIndex < 1 { this.surveyStopIndex = lineStopCount; };
    };
    this.PublishSurveySettings();
    this.NotifySelectedSurveyStop();
  }

  private func Record(kind: String) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let position: Vector4;
    let prefix: CName;
    let eventId: Int32;
    let confirmation: ref<NCTCSurveyWriteConfirmationCallback>;
    if !IsDefined(player) || !IsDefined(quests) { return; };
    position = player.GetWorldPosition();
    prefix = StringToName("nctc_survey_" + kind + "_");
    quests.SetFact(StringToName(NameToString(prefix) + "x"), Cast<Int32>(position.X * 1000.00));
    quests.SetFact(StringToName(NameToString(prefix) + "y"), Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(StringToName(NameToString(prefix) + "z"), Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(StringToName(NameToString(prefix) + "yaw"), Cast<Int32>(player.GetWorldYaw() * 1000.00));
    quests.SetFact(StringToName(NameToString(prefix) + "valid"), 1);
    // Stop position is resolved against the live JSON by the CET survey
    // writer. No hard-coded passage table participates in new captures.
    quests.SetFact(n"nctc_survey_capture_line", this.GetSelectedLineNumber());
    quests.SetFact(n"nctc_survey_capture_stop_index", this.surveyStopIndex);
    if Equals(kind, "spawn") {
      quests.SetFact(n"nctc_survey_capture_point", 1);
    } else {
      if Equals(kind, "approach") {
        quests.SetFact(n"nctc_survey_capture_point", 2);
      } else {
        quests.SetFact(n"nctc_survey_capture_point", 3);
      };
    };
    quests.SetFact(n"nctc_survey_event_session", quests.GetFact(n"nctc_survey_runtime_session"));
    quests.SetFact(n"nctc_survey_event_kind", 1);
    eventId = quests.GetFact(n"nctc_survey_event_id") + 1;
    // The immediate prompt only confirms the key was captured. CET writes the
    // actual acknowledgement after the external JSON has been updated.
    quests.SetFact(n"nctc_survey_write_ack_event_id", -1);
    quests.SetFact(n"nctc_survey_event_id", eventId);
    confirmation = new NCTCSurveyWriteConfirmationCallback();
    confirmation.game = this.GetGameInstance(); confirmation.eventId = eventId; confirmation.kind = kind;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(confirmation, 0.75, false);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC survey queued: " + kind);
  }

  // Manual stops are road-position anchors. They deliberately do not inherit a
  // metro map lock: the metro mappin is often too far from the usable roadway.
  private func RecordManualStop() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
    let position: Vector4;
    let anchorPosition: Vector4;
    let locKey: String;
    let line: Int32 = this.GetSelectedLineNumber();
    if !IsDefined(player) || !IsDefined(quests) || line < 1 { return; };
    position = player.GetWorldPosition();
    quests.SetFact(n"nctc_manual_stop_line", line);
    quests.SetFact(n"nctc_manual_stop_color", EnumInt(this.draftLineColor));
    quests.SetFact(n"nctc_manual_stop_x", Cast<Int32>(position.X * 1000.00));
    quests.SetFact(n"nctc_manual_stop_y", Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(n"nctc_manual_stop_z", Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(n"nctc_manual_stop_loc_key", 0);
    if IsDefined(markers) && markers.GetTravelAnchorWithin(position, 100.00, locKey, anchorPosition) {
      quests.SetFact(n"nctc_manual_stop_loc_key", this.ParseTravelAnchorLocKey(locKey));
    };
    quests.SetFact(n"nctc_survey_event_session", quests.GetFact(n"nctc_survey_runtime_session"));
    quests.SetFact(n"nctc_survey_event_kind", 3);
    quests.SetFact(n"nctc_survey_event_id", quests.GetFact(n"nctc_survey_event_id") + 1);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC: manual stop saved for line " + ToString(line));
  }

  private func DeleteNearestStop() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let line: Int32 = this.GetSelectedLineNumber();
    let eventId: Int32;
    let confirmation: ref<NCTCSurveyWriteConfirmationCallback>;
    if !IsDefined(player) || !IsDefined(quests) || line < 1 { return; };
    // The survey selector is the only unambiguous identity when a line visits
    // the same fast-travel station more than once. Do not guess by LocKey.
    quests.SetFact(n"nctc_delete_stop_line", line);
    quests.SetFact(n"nctc_delete_stop_index", this.surveyStopIndex);
    quests.SetFact(n"nctc_survey_event_session", quests.GetFact(n"nctc_survey_runtime_session"));
    quests.SetFact(n"nctc_survey_event_kind", 4);
    eventId = quests.GetFact(n"nctc_survey_event_id") + 1;
    quests.SetFact(n"nctc_survey_write_ack_event_id", -1);
    quests.SetFact(n"nctc_survey_event_id", eventId);
    confirmation = new NCTCSurveyWriteConfirmationCallback();
    confirmation.game = this.GetGameInstance(); confirmation.eventId = eventId; confirmation.kind = "selected stop";
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(confirmation, 0.75, false);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC: deleting selected stop " + ToString(this.surveyStopIndex) + " on line " + ToString(line));
  }

  // This action edits only the selected stop's map/call anchor. Surveyed
  // driving data is keyed by the stable stop ID and is intentionally absent
  // from this event, so spawn/approach/berth cannot be overwritten.
  private func MoveSelectedStop() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
    let position: Vector4;
    let anchorPosition: Vector4;
    let locKey: String;
    let line: Int32 = this.GetSelectedLineNumber();
    let eventId: Int32;
    let confirmation: ref<NCTCSurveyWriteConfirmationCallback>;
    if !IsDefined(player) || !IsDefined(quests) || line < 1 { return; };
    position = player.GetWorldPosition();
    quests.SetFact(n"nctc_replace_stop_line", line);
    quests.SetFact(n"nctc_replace_stop_index", this.surveyStopIndex);
    quests.SetFact(n"nctc_replace_stop_x", Cast<Int32>(position.X * 1000.00));
    quests.SetFact(n"nctc_replace_stop_y", Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(n"nctc_replace_stop_z", Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(n"nctc_replace_stop_loc_key", 0);
    if IsDefined(markers) && markers.GetTravelAnchorWithin(position, 100.00, locKey, anchorPosition) {
      quests.SetFact(n"nctc_replace_stop_loc_key", this.ParseTravelAnchorLocKey(locKey));
    };
    quests.SetFact(n"nctc_survey_event_session", quests.GetFact(n"nctc_survey_runtime_session"));
    quests.SetFact(n"nctc_survey_event_kind", 6);
    eventId = quests.GetFact(n"nctc_survey_event_id") + 1;
    quests.SetFact(n"nctc_survey_write_ack_event_id", -1);
    quests.SetFact(n"nctc_survey_event_id", eventId);
    confirmation = new NCTCSurveyWriteConfirmationCallback();
    confirmation.game = this.GetGameInstance(); confirmation.eventId = eventId; confirmation.kind = "selected stop move";
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(confirmation, 0.75, false);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC: moving selected stop " + ToString(this.surveyStopIndex) + " on line " + ToString(line));
  }

  // A passage belongs to the route leg after the selected stop. It is never a
  // passenger stop: it has no mappin, LocKey, spawn, approach, or berth.
  private func RecordPassageAfterSelected() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let position: Vector4;
    let line: Int32 = this.GetSelectedLineNumber();
    let eventId: Int32;
    let confirmation: ref<NCTCSurveyWriteConfirmationCallback>;
    if !IsDefined(player) || !IsDefined(quests) || line < 1 { return; };
    position = player.GetWorldPosition();
    quests.SetFact(n"nctc_passage_line", line);
    quests.SetFact(n"nctc_passage_after_index", this.surveyStopIndex);
    quests.SetFact(n"nctc_passage_x", Cast<Int32>(position.X * 1000.00));
    quests.SetFact(n"nctc_passage_y", Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(n"nctc_passage_z", Cast<Int32>(position.Z * 1000.00));
    // Face the direction the bus must travel through this point. Like berth
    // yaw, this compensates for the Mahir pivot stopping short of raw targets.
    quests.SetFact(n"nctc_passage_yaw", Cast<Int32>(player.GetWorldYaw() * 1000.00));
    quests.SetFact(n"nctc_survey_event_session", quests.GetFact(n"nctc_survey_runtime_session"));
    quests.SetFact(n"nctc_survey_event_kind", 7);
    eventId = quests.GetFact(n"nctc_survey_event_id") + 1;
    quests.SetFact(n"nctc_survey_write_ack_event_id", -1);
    quests.SetFact(n"nctc_survey_event_id", eventId);
    confirmation = new NCTCSurveyWriteConfirmationCallback();
    confirmation.game = this.GetGameInstance(); confirmation.eventId = eventId; confirmation.kind = "passage point";
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(confirmation, 0.75, false);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC: recording passage after stop " + ToString(this.surveyStopIndex) + " on line " + ToString(line));
  }

  private func DeleteNearestPassage() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let position: Vector4;
    let line: Int32 = this.GetSelectedLineNumber();
    let eventId: Int32;
    let confirmation: ref<NCTCSurveyWriteConfirmationCallback>;
    if !IsDefined(player) || !IsDefined(quests) || line < 1 { return; };
    position = player.GetWorldPosition();
    quests.SetFact(n"nctc_delete_passage_line", line);
    quests.SetFact(n"nctc_delete_passage_x", Cast<Int32>(position.X * 1000.00));
    quests.SetFact(n"nctc_delete_passage_y", Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(n"nctc_delete_passage_z", Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(n"nctc_survey_event_session", quests.GetFact(n"nctc_survey_runtime_session"));
    quests.SetFact(n"nctc_survey_event_kind", 8);
    eventId = quests.GetFact(n"nctc_survey_event_id") + 1;
    quests.SetFact(n"nctc_survey_write_ack_event_id", -1);
    quests.SetFact(n"nctc_survey_event_id", eventId);
    confirmation = new NCTCSurveyWriteConfirmationCallback();
    confirmation.game = this.GetGameInstance(); confirmation.eventId = eventId; confirmation.kind = "deleted passage point";
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(confirmation, 0.75, false);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC: deleting nearest passage point on line " + ToString(line));
  }

  private func GetSelectedLineNumber() -> Int32 {
    return this.activeLineNumber;
  }

  // Called by a fast-travel terminal's F interaction while developer mode is
  // enabled. A draft stop is bound to that terminal's native LocKey.
  public func RecordTerminalStop(locKey: String, position: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let line: Int32 = this.GetSelectedLineNumber();
    let locKeyID: Int32 = this.ParseTravelAnchorLocKey(locKey);
    if !this.developerMode || !IsDefined(quests) || line < 1 || locKeyID < 0 { return false; };
    quests.SetFact(n"nctc_terminal_stop_line", line);
    quests.SetFact(n"nctc_terminal_stop_color", EnumInt(this.draftLineColor));
    quests.SetFact(n"nctc_terminal_stop_loc_key", locKeyID);
    quests.SetFact(n"nctc_terminal_stop_x", Cast<Int32>(position.X * 1000.00));
    quests.SetFact(n"nctc_terminal_stop_y", Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(n"nctc_terminal_stop_z", Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(n"nctc_survey_event_session", quests.GetFact(n"nctc_survey_runtime_session"));
    quests.SetFact(n"nctc_survey_event_kind", 9);
    quests.SetFact(n"nctc_survey_event_id", quests.GetFact(n"nctc_survey_event_id") + 1);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC line " + ToString(line) + ": terminal stop saved");
    return true;
  }

  public static func Get(game: GameInstance) -> ref<NCTCSettings> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<NCTCSettings>()) as NCTCSettings;
  }

  // Fast-travel points usually expose `LocKey#123`, while some metro points
  // expose the raw numeric key.  Both forms identify the same localized name.
  // Treating the raw form as zero silently turned a valid moved stop into a
  // manual, unnamed stop.
  private func ParseTravelAnchorLocKey(value: String) -> Int32 {
    let parsed: Int32 = StringToInt(StrAfterFirst(value, "LocKey#"), 0);
    if parsed > 0 { return parsed; };
    return StringToInt(value, 0);
  }

  public func ShouldRecordTerminalStops() -> Bool {
    return this.developerMode && Equals(this.developerTerminalAction, NCTCDeveloperTerminalAction.RecordStop);
  }

  @if(ModuleExists("ModSettingsModule"))
  private func ClearBeginDraftSetting() -> Void {
    let variable: ref<ConfigVar>;
    for variable in ModSettings.GetVars(n"Night City Transit Corporation", n"Developer mode") {
      if Equals(variable.GetName(), n"beginDraftLine") {
        (variable as ModConfigVarBool).SetValue(false);
        return;
      };
    };
  }
  @if(!ModuleExists("ModSettingsModule"))
  private func ClearBeginDraftSetting() -> Void {}

  public static func Notify(game: GameInstance, text: String) -> Void {
    let message: SimpleScreenMessage;
    let defs: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
    message.isShown = true; message.duration = 2.50; message.message = text;
    GameInstance.GetBlackboardSystem(game).Get(defs.UI_Notifications).SetVariant(defs.UI_Notifications.WarningMessage, ToVariant(message), true);
  }

  @if(ModuleExists("ModSettingsModule"))
  private func RegisterSettings() -> Void {
    ModSettings.RegisterListenerToClass(this);
    ModSettings.RegisterListenerToModifications(this);
  }
  @if(!ModuleExists("ModSettingsModule"))
  private func RegisterSettings() -> Void {}

  @if(ModuleExists("ModSettingsModule"))
  private func UnregisterSettings() -> Void {
    ModSettings.UnregisterListenerToClass(this);
    ModSettings.UnregisterListenerToModifications(this);
  }
  @if(!ModuleExists("ModSettingsModule"))
  private func UnregisterSettings() -> Void {}
}
