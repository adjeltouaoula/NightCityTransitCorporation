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
  @runtimeProperty("ModSettings.displayName", "Developer mode")
  @runtimeProperty("ModSettings.description", "Enables NCTC survey captures. Numpad 1 records spawn, 2 approach, and 3 berth.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.category.order", "0")
  public let developerMode: Bool = false;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Developer terminal action")
  @runtimeProperty("ModSettings.description", "Choose whether F at a terminal calls the bus or records that terminal as the next draft stop.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.displayValues.CallBus", "Call bus")
  @runtimeProperty("ModSettings.displayValues.RecordStop", "Record new stop")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let developerTerminalAction: NCTCDeveloperTerminalAction = NCTCDeveloperTerminalAction.CallBus;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Survey line")
  @runtimeProperty("ModSettings.description", "Line for the passage currently being surveyed.")
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
  @runtimeProperty("ModSettings.displayName", "Add manual stop")
  @runtimeProperty("ModSettings.description", "Adds a stop at V's current position. Use this for metro stations or roadside stops; nearby services are grouped into one hub.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let addManualStopKey: EInputKey = EInputKey.IK_NumPad4;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "Delete nearest stop")
  @runtimeProperty("ModSettings.description", "Deletes the nearest stop for the active line, within 25 metres. Other lines at the same hub are kept.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let deleteNearestStopKey: EInputKey = EInputKey.IK_NumPad5;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "New line number")
  @runtimeProperty("ModSettings.description", "Number for the draft line being created. Set it before recording its first stop.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "999")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let draftLineNumber: Int32 = 100;

  @runtimeProperty("ModSettings.mod", "Night City Transit Corporation")
  @runtimeProperty("ModSettings.displayName", "New line color")
  @runtimeProperty("ModSettings.description", "Applied once, when Create / replace draft line records its first stop. Later changes do not alter an existing line.")
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
  @runtimeProperty("ModSettings.displayName", "Create / replace draft line")
  @runtimeProperty("ModSettings.description", "Enable this, then press New stop once. That press creates an empty draft line and adds its first stop. Later New stop presses append stops in order.")
  @runtimeProperty("ModSettings.category", "Developer mode")
  @runtimeProperty("ModSettings.dependency", "developerMode")
  public let beginDraftLine: Bool = false;

  private func OnAttach() -> Void {
    this.RegisterSettings();
    this.PublishSurveySettings();
    this.UpdateDeveloperVisibility();
    GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnSurveyKeyInput");
  }

  private func OnDetach() -> Void {
    GameInstance.GetCallbackSystem().UnregisterCallback(n"Input/Key", this, n"OnSurveyKeyInput");
    this.UnregisterSettings();
  }

  @if(ModuleExists("ModSettingsModule"))
  public func OnModSettingsChange() -> Void {
    this.PublishSurveySettings();
    this.UpdateDeveloperVisibility();
    if this.developerMode { this.NotifySelectedSurveyStop(); };
  }

  private func PublishSurveySettings() -> Void {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    if !IsDefined(quests) { return; };
    quests.SetFact(n"nctc_survey_developer_mode", this.developerMode ? 1 : 0);
    quests.SetFact(n"nctc_survey_line", EnumInt(this.surveyLine));
    quests.SetFact(n"nctc_survey_passage", EnumInt(this.surveyPassage));
  }

  private func NotifySelectedSurveyStop() -> Void {
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
    let line: Int32 = this.GetSelectedLineNumber();
    if !IsDefined(markers) || line < 1 { return; };
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC survey: line " + ToString(line) + " · stop " + ToString(this.surveyStopIndex) + " · " + markers.GetSurveyStopName(line, this.surveyStopIndex));
  }

  @if(ModuleExists("ModSettingsModule"))
  private func UpdateDeveloperVisibility() -> Void {
    let variable: ref<ConfigVar>;
    // A single category prevents empty developer headings leaking into the
    // normal configuration screen. Only the master switch stays visible.
    for variable in ModSettings.GetVars(n"Night City Transit Corporation", n"Developer mode") {
      if Equals(variable.GetName(), n"surveyPassage") { variable.SetVisible(false); }
      else if !Equals(variable.GetName(), n"developerMode") { variable.SetVisible(this.developerMode); };
    };
  }
  @if(!ModuleExists("ModSettingsModule"))
  private func UpdateDeveloperVisibility() -> Void {}

  protected cb func OnSurveyKeyInput(event: ref<KeyInputEvent>) -> Void {
    if !this.developerMode || !Equals(event.GetAction(), EInputAction.IACT_Press) { return; };
    if Equals(event.GetKey(), this.recordSpawnKey) { this.Record("spawn"); return; };
    if Equals(event.GetKey(), this.recordApproachKey) { this.Record("approach"); return; };
    if Equals(event.GetKey(), this.recordBerthKey) { this.Record("berth"); return; };
    if Equals(event.GetKey(), this.addManualStopKey) { this.RecordManualStop(); return; };
    if Equals(event.GetKey(), this.deleteNearestStopKey) { this.DeleteNearestStop(); };
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
    let position: Vector4;
    let line: Int32 = this.GetSelectedLineNumber();
    if !IsDefined(player) || !IsDefined(quests) || line < 1 { return; };
    position = player.GetWorldPosition();
    quests.SetFact(n"nctc_manual_stop_line", line);
    quests.SetFact(n"nctc_manual_stop_x", Cast<Int32>(position.X * 1000.00));
    quests.SetFact(n"nctc_manual_stop_y", Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(n"nctc_manual_stop_z", Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(n"nctc_survey_event_kind", 3);
    quests.SetFact(n"nctc_survey_event_id", quests.GetFact(n"nctc_survey_event_id") + 1);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC: manual stop saved for line " + ToString(line));
  }

  private func DeleteNearestStop() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let markers: ref<NCTCMapMarkerSystem> = NCTCMapMarkerSystem.GetInstance(this.GetGameInstance());
    let position: Vector4;
    let anchorPosition: Vector4;
    let locKey: String;
    let line: Int32 = this.GetSelectedLineNumber();
    if !IsDefined(player) || !IsDefined(quests) || line < 1 { return; };
    position = player.GetWorldPosition();
    quests.SetFact(n"nctc_delete_stop_line", line);
    quests.SetFact(n"nctc_delete_stop_x", Cast<Int32>(position.X * 1000.00));
    quests.SetFact(n"nctc_delete_stop_y", Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(n"nctc_delete_stop_z", Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(n"nctc_delete_stop_loc_key", -1);
    if IsDefined(markers) && markers.GetNearestTravelAnchor(position, locKey, anchorPosition) {
      quests.SetFact(n"nctc_delete_stop_loc_key", StringToInt(StrAfterFirst(locKey, "LocKey#"), -1));
    };
    quests.SetFact(n"nctc_survey_event_kind", 4);
    quests.SetFact(n"nctc_survey_event_id", quests.GetFact(n"nctc_survey_event_id") + 1);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC: deleting nearest stop for line " + ToString(line));
  }

  // The draft number is reserved for a genuinely new line. Editing an
  // existing network line must always use the Survey line selector.
  private func GetSelectedLineNumber() -> Int32 {
    switch this.surveyLine {
      case NCTCSurveyLine.Line17: return 17;
      case NCTCSurveyLine.Line22: return 22;
      case NCTCSurveyLine.Line23: return 23;
      case NCTCSurveyLine.Line51: return 51;
      case NCTCSurveyLine.Line68: return 68;
      case NCTCSurveyLine.Line72: return 72;
    };
    return 0;
  }

  // Called by a fast-travel terminal's F interaction while developer mode is
  // enabled. A draft stop is bound to that terminal's native LocKey.
  public func RecordTerminalStop(locKey: String, position: Vector4) -> Bool {
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
    let count: Int32;
    let line: Int32 = this.draftLineNumber;
    let prefix: String;
    let locKeyID: Int32 = StringToInt(StrAfterFirst(locKey, "LocKey#"), -1);
    if !this.developerMode || !IsDefined(quests) || line < 1 || locKeyID < 0 { return false; };
    if this.beginDraftLine {
      quests.SetFact(n"nctc_draft_line_number", line);
      quests.SetFact(n"nctc_draft_line_stop_count", 0);
      quests.SetFact(n"nctc_draft_line_color", EnumInt(this.draftLineColor));
      this.beginDraftLine = false;
      this.ClearBeginDraftSetting();
    };
    if !Equals(quests.GetFact(n"nctc_draft_line_number"), line) {
      NCTCSettings.Notify(this.GetGameInstance(), "NCTC: enable Create / replace draft line first");
      return false;
    };
    count = quests.GetFact(n"nctc_draft_line_stop_count");
    prefix = "nctc_draft_line_" + ToString(line) + "_stop_" + ToString(count) + "_";
    quests.SetFact(StringToName(prefix + "loc_key"), locKeyID);
    quests.SetFact(StringToName(prefix + "x"), Cast<Int32>(position.X * 1000.00));
    quests.SetFact(StringToName(prefix + "y"), Cast<Int32>(position.Y * 1000.00));
    quests.SetFact(StringToName(prefix + "z"), Cast<Int32>(position.Z * 1000.00));
    quests.SetFact(n"nctc_draft_line_stop_count", count + 1);
    quests.SetFact(n"nctc_survey_event_kind", 2);
    quests.SetFact(n"nctc_survey_event_id", quests.GetFact(n"nctc_survey_event_id") + 1);
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC line " + ToString(line) + ": stop " + ToString(count + 1) + " saved");
    return true;
  }

  public static func Get(game: GameInstance) -> ref<NCTCSettings> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(NameOf<NCTCSettings>()) as NCTCSettings;
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

  private static func Notify(game: GameInstance, text: String) -> Void {
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
