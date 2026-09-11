from pathlib import Path


def replace_one(path, old, new):
    p = Path(path)
    s = p.read_text()
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one occurrence, got {count}: {old[:120]!r}")
    p.write_text(s.replace(old, new))

# Runtime marker only; driving logic stays exactly r374t for this calibration build.
replace_one(
    "source/redscript/NCTC/NCTCTransitSystem.reds",
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37420);',
    'GameInstance.GetQuestsSystem(this.bus.GetGame()).SetFact(n"nctc_dev_build_revision", 37421);'
)

settings = Path("source/redscript/NCTC/NCTCSettings.reds")
s = settings.read_text()

def sone(old, new):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"NCTCSettings.reds: expected one occurrence, got {count}: {old[:120]!r}")
    s = s.replace(old, new)

sone(
    '@runtimeProperty("ModSettings.description", "Developer-only shortcut. Switches NumPad 3 between Bay Point 1 and Bay Point 2.")',
    '@runtimeProperty("ModSettings.description", "Developer-only shortcut. Cycles NumPad 3 through Bay Point 1, Bay Point 2, Width A and Width B.")'
)

sone(
    '  private let lastBayPoint2EditMode: Bool;\n',
    '  private let lastBayPoint2EditMode: Bool;\n  private let bayEditorMode: Int32;\n'
)

sone(
'''    this.RegisterSettings();
    this.lastBayPoint2EditMode = this.editBayPoint2;
    this.PublishSurveySettings();''',
'''    this.RegisterSettings();
    this.lastBayPoint2EditMode = this.editBayPoint2;
    this.bayEditorMode = this.editBayPoint2 ? 1 : 0;
    this.PublishSurveySettings();'''
)

sone(
'''    if this.developerMode && NotEquals(this.editBayPoint2, this.lastBayPoint2EditMode) {
      this.lastBayPoint2EditMode = this.editBayPoint2;
      NCTCSettings.Notify(this.GetGameInstance(), this.editBayPoint2 ? "NCTC - Editing Bay Point 2" : "NCTC - Editing Bay Point 1");
    };''',
'''    if this.developerMode && NotEquals(this.editBayPoint2, this.lastBayPoint2EditMode) {
      this.lastBayPoint2EditMode = this.editBayPoint2;
      this.bayEditorMode = this.editBayPoint2 ? 1 : 0;
      NCTCSettings.Notify(this.GetGameInstance(), "NCTC - Editing " + this.GetBayEditorName());
    };'''
)

sone(
    '    quests.SetFact(n"nctc_survey_edit_bay_point2", this.editBayPoint2 ? 1 : 0);\n    quests.SetFact(n"nctc_survey_passage", EnumInt(this.surveyPassage));',
    '    quests.SetFact(n"nctc_survey_edit_bay_point2", this.editBayPoint2 ? 1 : 0);\n    quests.SetFact(n"nctc_survey_bay_edit_mode", this.bayEditorMode);\n    quests.SetFact(n"nctc_survey_passage", EnumInt(this.surveyPassage));'
)

sone(
    '    NCTCSettings.Notify(this.GetGameInstance(), "NCTC survey: line " + ToString(line) + " · stop " + ToString(this.surveyStopIndex) + " · " + markers.GetSurveyStopName(line, this.surveyStopIndex) + " · editing " + (this.editBayPoint2 ? "Bay Point 2" : "Bay Point 1"));',
    '    NCTCSettings.Notify(this.GetGameInstance(), "NCTC survey: line " + ToString(line) + " · stop " + ToString(this.surveyStopIndex) + " · " + markers.GetSurveyStopName(line, this.surveyStopIndex) + " · editing " + this.GetBayEditorName());'
)

sone(
'''  private func ToggleBayPointEditor() -> Void {
    this.editBayPoint2 = !this.editBayPoint2;
    this.lastBayPoint2EditMode = this.editBayPoint2;
    this.PublishSurveySettings();
    NCTCSettings.Notify(this.GetGameInstance(), this.editBayPoint2 ? "NCTC - Editing Bay Point 2" : "NCTC - Editing Bay Point 1");
  }
''',
'''  private func GetBayEditorName() -> String {
    if Equals(this.bayEditorMode, 1) { return "Bay Point 2"; };
    if Equals(this.bayEditorMode, 2) { return "Bay Width A"; };
    if Equals(this.bayEditorMode, 3) { return "Bay Width B"; };
    return "Bay Point 1";
  }

  private func ToggleBayPointEditor() -> Void {
    this.bayEditorMode += 1;
    if this.bayEditorMode > 3 { this.bayEditorMode = 0; };
    this.editBayPoint2 = Equals(this.bayEditorMode, 1);
    this.lastBayPoint2EditMode = this.editBayPoint2;
    this.PublishSurveySettings();
    NCTCSettings.Notify(this.GetGameInstance(), "NCTC - Editing " + this.GetBayEditorName());
  }
'''
)

sone(
    '        NCTCSettings.Notify(this.game, "NCTC survey confirmed: " + (Equals(point, 1) ? "spawn" : Equals(point, 2) ? "approach" : Equals(point, 4) ? "Bay Point 2" : "Bay Point 1"));',
    '        NCTCSettings.Notify(this.game, "NCTC survey confirmed: " + (Equals(point, 1) ? "spawn" : Equals(point, 2) ? "approach" : Equals(point, 4) ? "Bay Point 2" : Equals(point, 5) ? "Bay Width A" : Equals(point, 6) ? "Bay Width B" : "Bay Point 1"));'
)

settings.write_text(s)

cet = Path("source/cet/nctc_survey/init.lua")
s = cet.read_text()

def cone(old, new):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"init.lua: expected one occurrence, got {count}: {old[:120]!r}")
    s = s.replace(old, new)

cone(
'''      if vector_has_position(capture.berth) then saved.berth = capture.berth end
      if vector_has_position(capture.berth2) then saved.berth2 = capture.berth2 end
      saved.eventId = capture.eventId or saved.eventId''',
'''      if vector_has_position(capture.berth) then saved.berth = capture.berth end
      if vector_has_position(capture.berth2) then saved.berth2 = capture.berth2 end
      if vector_has_position(capture.bayWidthA) then saved.bayWidthA = capture.bayWidthA end
      if vector_has_position(capture.bayWidthB) then saved.bayWidthB = capture.bayWidthB end
      saved.eventId = capture.eventId or saved.eventId'''
)

cone(
'''local function update_capture_point(capture, point, value)
  if point == 1 then
    capture.spawn = value
    return "spawn"
  elseif point == 2 then
    capture.approach = value
    return "approach"
  elseif point == 4 then
    capture.berth2 = value
    return "bay point 2"
  end
  capture.berth = value
  return "bay point 1"
end''',
'''local function update_capture_point(capture, point, value)
  if point == 1 then
    capture.spawn = value
    return "spawn"
  elseif point == 2 then
    capture.approach = value
    return "approach"
  elseif point == 4 then
    capture.berth2 = value
    return "bay point 2"
  elseif point == 5 then
    capture.bayWidthA = value
    return "bay width A"
  elseif point == 6 then
    capture.bayWidthB = value
    return "bay width B"
  end
  capture.berth = value
  return "bay point 1"
end'''
)

cone(
'''  local point = { x = round3(position.x), y = round3(position.y), z = round3(position.z), yaw = round3(player:GetWorldYaw()) }
  local point_code = kind == "spawn" and 1 or (kind == "approach" and 2 or ((fact(quests, "nctc_survey_edit_bay_point2") == 1) and 4 or 3))
  local point_name = update_capture_point(capture, point_code, point)
  network.revision = (network.revision or 0) + 1
  if write_network(network) then
    set_fact(quests, "nctc_survey_direct_notice_point", point_code)
    set_fact(quests, "nctc_survey_direct_notice_id", fact(quests, "nctc_survey_direct_notice_id") + 1)
    log("direct saved " .. point_name .. " L" .. tostring(line) .. " stop " .. tostring(stop_index) .. "/" .. tostring(count)
      .. " at (" .. tostring(point.x) .. ", " .. tostring(point.y) .. ", " .. tostring(point.z) .. ")")
  end''',
'''  local point = { x = round3(position.x), y = round3(position.y), z = round3(position.z), yaw = round3(player:GetWorldYaw()) }
  local editor_mode = fact(quests, "nctc_survey_bay_edit_mode")
  local point_code = 3
  if kind == "spawn" then point_code = 1
  elseif kind == "approach" then point_code = 2
  elseif editor_mode == 1 then point_code = 4
  elseif editor_mode == 2 then point_code = 5
  elseif editor_mode == 3 then point_code = 6
  end
  local point_name = update_capture_point(capture, point_code, point)
  network.revision = (network.revision or 0) + 1
  if write_network(network) then
    set_fact(quests, "nctc_survey_direct_notice_point", point_code)
    set_fact(quests, "nctc_survey_direct_notice_id", fact(quests, "nctc_survey_direct_notice_id") + 1)
    log("direct saved " .. point_name .. " L" .. tostring(line) .. " stop " .. tostring(stop_index) .. "/" .. tostring(count)
      .. " at (" .. tostring(point.x) .. ", " .. tostring(point.y) .. ", " .. tostring(point.z) .. ")")
    if vector_has_position(capture.bayWidthA) and vector_has_position(capture.bayWidthB) then
      local dx = (capture.bayWidthA.x or 0) - (capture.bayWidthB.x or 0)
      local dy = (capture.bayWidthA.y or 0) - (capture.bayWidthB.y or 0)
      local width = math.sqrt(dx * dx + dy * dy)
      log("BAY WIDTH CALIBRATION L" .. tostring(line)
        .. " stop " .. tostring(stop_index) .. "/" .. tostring(count)
        .. " stopId=" .. tostring(target.id)
        .. " name=" .. tostring(target.name or capture.stopName or "")
        .. string.format(" width=%.3fm", width)
        .. string.format(" A=(%.3f, %.3f) B=(%.3f, %.3f)", capture.bayWidthA.x or 0, capture.bayWidthA.y or 0, capture.bayWidthB.x or 0, capture.bayWidthB.y or 0))
    end
  end'''
)

cone(
'''  if revision == 37420 then
    log("NCTC runtime build=37420 r374t real-bus S-curve bay path")''',
'''  if revision == 37421 then
    log("NCTC runtime build=37421 r374u bay-width calibration")
  elseif revision == 37420 then
    log("NCTC runtime build=37420 r374t real-bus S-curve bay path")'''
)

cet.write_text(s)

print("r374u calibration patch applied")
