-- NC Transit Pocket Guide v1
-- Dev-only CET prototype. The guide reads the network snapshot already
-- published by nctc_survey into quest facts, so it follows the active network
-- without keeping a second hard-coded route list.

local GUIDE = {
  open = false,
  network = nil,
  lines = {},
  lineOrder = {},
  stationLines = {},
  selectedLine = nil,
  error = nil
}

local function fact(quests, name)
  if not quests then return 0 end

  local ok, value = pcall(function() return quests:GetFactStr(name) end)
  value = tonumber(value)
  if ok and value ~= nil then return math.floor(value) end

  ok, value = pcall(function() return quests:GetFact(CName.new(name)) end)
  value = tonumber(value)
  if ok and value ~= nil then return math.floor(value) end

  ok, value = pcall(function() return quests:GetFact(name) end)
  value = tonumber(value)
  if ok and value ~= nil then return math.floor(value) end

  return 0
end

local function line_less(left, right)
  local leftNumber = tonumber(left)
  local rightNumber = tonumber(right)
  if leftNumber ~= nil and rightNumber ~= nil then return leftNumber < rightNumber end
  if leftNumber ~= nil then return true end
  if rightNumber ~= nil then return false end
  return tostring(left) < tostring(right)
end

local function stop_less(left, right)
  if left.sequence ~= right.sequence then return left.sequence < right.sequence end
  return left.id < right.id
end

local function station_key(stop)
  if stop.locKey and stop.locKey > 0 then
    return "loc:" .. tostring(stop.locKey)
  end

  -- Stops without a LocKey can still represent the same physical transfer.
  -- The published positions are millimetres; grouping into five-metre cells
  -- is tight enough for one stop while avoiding tiny survey differences.
  local cell = 5000
  local x = math.floor((stop.x + (stop.x >= 0 and cell / 2 or -cell / 2)) / cell)
  local y = math.floor((stop.y + (stop.y >= 0 and cell / 2 or -cell / 2)) / cell)
  local z = math.floor((stop.z + (stop.z >= 0 and cell / 2 or -cell / 2)) / cell)
  return string.format("pos:%d:%d:%d", x, y, z)
end

local function localized_stop_name(stop)
  if stop.locKey and stop.locKey > 0 and type(GetLocalizedText) == "function" then
    local key = "LocKey#" .. tostring(stop.locKey)
    local ok, value = pcall(function() return GetLocalizedText(key) end)
    if ok and type(value) == "string" and value ~= "" and value ~= key then
      return value
    end
  end

  if stop.locKey and stop.locKey > 0 then
    return "LocKey #" .. tostring(stop.locKey)
  end
  return "Stop " .. tostring(stop.id)
end

local function rebuild_indexes(stops)
  GUIDE.lines = {}
  GUIDE.lineOrder = {}
  GUIDE.stationLines = {}

  for _, stop in ipairs(stops) do
    local line = tostring(stop.line)
    if GUIDE.lines[line] == nil then
      GUIDE.lines[line] = {}
      table.insert(GUIDE.lineOrder, line)
    end
    table.insert(GUIDE.lines[line], stop)

    local key = station_key(stop)
    GUIDE.stationLines[key] = GUIDE.stationLines[key] or {}
    GUIDE.stationLines[key][line] = true
  end

  table.sort(GUIDE.lineOrder, line_less)
  for _, line in ipairs(GUIDE.lineOrder) do
    table.sort(GUIDE.lines[line], stop_less)
  end

  if GUIDE.selectedLine == nil or GUIDE.lines[GUIDE.selectedLine] == nil then
    GUIDE.selectedLine = GUIDE.lineOrder[1]
  end
end

local function reload_network()
  GUIDE.error = nil
  GUIDE.network = nil

  local quests = Game.GetQuestsSystem()
  if not quests then
    GUIDE.error = "Game network is not available yet. Load a save and press Refresh."
    return false
  end

  if fact(quests, "nctc_external_network_ready") ~= 1 then
    GUIDE.error = "NCTC network is not ready yet. Load a save and press Refresh."
    return false
  end

  local count = fact(quests, "nctc_external_network_stop_count")
  if count <= 0 then
    GUIDE.error = "The active NCTC network contains no published stops."
    return false
  end

  local stops = {}
  for index = 0, count - 1 do
    local prefix = "nctc_external_stop_" .. tostring(index) .. "_"
    local line = fact(quests, prefix .. "line")
    local id = fact(quests, prefix .. "id")
    if line ~= 0 and id ~= 0 then
      table.insert(stops, {
        line = line,
        id = id,
        sequence = fact(quests, prefix .. "sequence"),
        locKey = fact(quests, prefix .. "loc_key"),
        x = fact(quests, prefix .. "x"),
        y = fact(quests, prefix .. "y"),
        z = fact(quests, prefix .. "z")
      })
    end
  end

  if #stops == 0 then
    GUIDE.error = "NCTC published the network, but no usable line stops were found."
    return false
  end

  GUIDE.network = {
    revision = fact(quests, "nctc_external_network_revision"),
    stops = stops
  }
  rebuild_indexes(stops)
  return true
end

local function transfer_lines(stop, currentLine)
  local station = GUIDE.stationLines[station_key(stop)] or {}
  local result = {}
  for line, present in pairs(station) do
    if present and line ~= currentLine then table.insert(result, line) end
  end
  table.sort(result, line_less)
  return result
end

local function draw_line_buttons()
  if #GUIDE.lineOrder == 0 then return end

  ImGui.Text("LINES")
  for index, line in ipairs(GUIDE.lineOrder) do
    local prefix = line == GUIDE.selectedLine and "> Line " or "Line "
    if ImGui.Button(prefix .. line .. "##nctc_line_" .. line, 92, 30) then
      GUIDE.selectedLine = line
    end
    if index % 6 ~= 0 and index < #GUIDE.lineOrder then
      ImGui.SameLine()
    end
  end
end

local function draw_selected_line()
  local line = GUIDE.selectedLine
  local stops = line and GUIDE.lines[line] or nil
  if not stops then return end

  ImGui.Separator()
  ImGui.Text("LINE " .. tostring(line) .. "  |  " .. tostring(#stops) .. " stops")
  ImGui.Separator()

  ImGui.BeginChild("##nctc_pocket_route", 0, 0, true)
  for index, stop in ipairs(stops) do
    local name = localized_stop_name(stop)
    local sequence = stop.sequence > 0 and stop.sequence or index
    ImGui.Text(string.format("%02d   o   %s", sequence, name))

    local transfers = transfer_lines(stop, line)
    if #transfers > 0 then
      ImGui.SameLine()
      ImGui.Text("   change: L" .. table.concat(transfers, " / L"))
    end

    if index < #stops then ImGui.Text("     |") end
  end
  ImGui.EndChild()
end

local function draw_guide()
  ImGui.Text("NIGHT CITY TRANSIT CORPORATION")
  ImGui.Text("NC TRANSIT POCKET GUIDE")
  ImGui.Separator()

  if ImGui.Button("Refresh network##nctc_pocket_refresh", 150, 28) then
    reload_network()
  end

  if GUIDE.network ~= nil then
    ImGui.SameLine()
    ImGui.Text("Network revision: " .. tostring(GUIDE.network.revision))
  end

  if GUIDE.error ~= nil then
    ImGui.Separator()
    ImGui.Text(GUIDE.error)
    return
  end

  draw_line_buttons()
  draw_selected_line()
end

registerForEvent("onDraw", function()
  if not GUIDE.open then return end

  ImGui.SetNextWindowSize(760, 620, ImGuiCond.FirstUseEver)
  if ImGui.Begin("NC Transit Pocket Guide##NCTCPocketGuide") then
    draw_guide()
  end
  ImGui.End()
end)

-- CET recommends inputs for responsive bindings. This registration is kept at
-- Lua root level so it is discoverable in CET > Bindings.
registerInput("nctc_pocket_guide_toggle", "NCTC: NC Transit Pocket Guide", function(down)
  if not down then return end
  GUIDE.open = not GUIDE.open
  if GUIDE.open then reload_network() end
end)

print("[NCTC Pocket Guide] v1 loaded; bind 'NCTC: NC Transit Pocket Guide' in CET Bindings.")
