-- NC Transit Pocket Guide v1
-- Dev-only CET UI. The network data is supplied by nctc_survey/init.lua so
-- this guide always reads the same active network used by the bus runtime.

local GUIDE = {
  open = false,
  initialized = false,
  network = nil,
  lines = {},
  lineOrder = {},
  stationLines = {},
  selectedLine = nil,
  error = nil
}

local function as_line(value)
  if value == nil then return nil end
  local numeric = tonumber(value)
  if numeric ~= nil then return tostring(math.floor(numeric)) end
  local text = tostring(value)
  if text == "" then return nil end
  return text
end

local function line_less(left, right)
  local leftNumber = tonumber(left)
  local rightNumber = tonumber(right)
  if leftNumber ~= nil and rightNumber ~= nil then return leftNumber < rightNumber end
  if leftNumber ~= nil then return true end
  if rightNumber ~= nil then return false end
  return left < right
end

local function station_key(stop)
  if type(stop) ~= "table" then return "unknown" end
  if stop.hubId ~= nil and tostring(stop.hubId) ~= "" then
    return "hub:" .. tostring(stop.hubId)
  end
  if stop.locKey ~= nil and tostring(stop.locKey) ~= "" then
    return "loc:" .. tostring(stop.locKey)
  end
  if type(stop.position) == "table" then
    return string.format(
      "pos:%.1f:%.1f:%.1f",
      tonumber(stop.position.x) or 0.0,
      tonumber(stop.position.y) or 0.0,
      tonumber(stop.position.z) or 0.0)
  end
  return "id:" .. tostring(stop.id or "unknown")
end

local function localized_stop_name(stop)
  if type(stop) ~= "table" then return "Unknown stop" end

  if type(stop.stopName) == "string" and stop.stopName ~= "" then
    return stop.stopName
  end
  if type(stop.name) == "string" and stop.name ~= "" then
    return stop.name
  end

  if stop.locKey ~= nil then
    local key = tostring(stop.locKey)
    if type(GetLocalizedText) == "function" then
      local ok, value = pcall(function()
        return GetLocalizedText("LocKey#" .. key)
      end)
      if ok and type(value) == "string" and value ~= "" and value ~= ("LocKey#" .. key) then
        return value
      end
    end
    return "LocKey #" .. key
  end

  return "Stop " .. tostring(stop.id or "?")
end

local function stop_less(left, right)
  local leftSequence = tonumber(left.sequence) or math.huge
  local rightSequence = tonumber(right.sequence) or math.huge
  if leftSequence ~= rightSequence then return leftSequence < rightSequence end
  return (tonumber(left.id) or math.huge) < (tonumber(right.id) or math.huge)
end

local function index_network(network)
  GUIDE.lines = {}
  GUIDE.lineOrder = {}
  GUIDE.stationLines = {}

  for _, stop in ipairs(network.stops or {}) do
    local line = as_line(stop.line)
    if line ~= nil then
      if GUIDE.lines[line] == nil then
        GUIDE.lines[line] = {}
        table.insert(GUIDE.lineOrder, line)
      end
      table.insert(GUIDE.lines[line], stop)

      local key = station_key(stop)
      GUIDE.stationLines[key] = GUIDE.stationLines[key] or {}
      GUIDE.stationLines[key][line] = true
    end
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

  local provider = _G.NCTC_PocketGuideNetworkProvider
  if type(provider) ~= "function" then
    GUIDE.network = nil
    GUIDE.error = "Network provider is not available."
    return false
  end

  local ok, network = pcall(provider)
  if not ok then
    GUIDE.network = nil
    GUIDE.error = "Network is not ready yet. Load a save, then press Refresh."
    return false
  end
  if type(network) ~= "table" then
    GUIDE.network = nil
    GUIDE.error = "Network provider returned invalid data."
    return false
  end

  GUIDE.network = network
  index_network(network)
  if #GUIDE.lineOrder == 0 then
    GUIDE.error = "No transit lines were found in the active network."
    return false
  end
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
    local label = (line == GUIDE.selectedLine and "> Line " or "Line ") .. line
    if ImGui.Button(label .. "##nctc_line_" .. line, 92, 30) then
      GUIDE.selectedLine = line
    end
    if index % 6 ~= 0 and index < #GUIDE.lineOrder then ImGui.SameLine() end
  end
end

local function draw_selected_line()
  local line = GUIDE.selectedLine
  local stops = line and GUIDE.lines[line] or nil
  if not stops then return end

  ImGui.Separator()
  ImGui.Text("LINE " .. tostring(line) .. "  |  " .. tostring(#stops) .. " stops")
  ImGui.Separator()

  if ImGui.BeginChild("##nctc_pocket_route", 0, 0, true) then
    for index, stop in ipairs(stops) do
      local sequence = tonumber(stop.sequence) or index
      local name = localized_stop_name(stop)
      ImGui.Text(string.format("%02d   o   %s", sequence, name))

      local transfers = transfer_lines(stop, line)
      if #transfers > 0 then
        ImGui.SameLine()
        ImGui.Text("   change: L" .. table.concat(transfers, " / L"))
      end

      if index < #stops then ImGui.Text("     |") end
    end
  end
  ImGui.EndChild()
end

local function draw_guide()
  ImGui.Text("NIGHT CITY TRANSIT CORPORATION")
  ImGui.Text("NC TRANSIT POCKET GUIDE")
  ImGui.Separator()

  if ImGui.Button("Refresh network##nctc_pocket_refresh", 150, 28) then reload_network() end
  ImGui.SameLine()
  if GUIDE.network ~= nil then
    ImGui.Text("Active network revision: " .. tostring(GUIDE.network.revision or "unknown"))
  end

  if GUIDE.error ~= nil then
    ImGui.Separator()
    ImGui.Text(GUIDE.error)
    return
  end

  draw_line_buttons()
  draw_selected_line()
end

registerForEvent("onInit", function()
  GUIDE.initialized = true
end)

registerForEvent("onDraw", function()
  if not GUIDE.open then return end

  ImGui.SetNextWindowSize(760, 620, ImGuiCond.FirstUseEver)
  if ImGui.Begin("NC Transit Pocket Guide##NCTCPocketGuide") then
    draw_guide()
  end
  ImGui.End()
end)

-- Inputs must be registered while CET loads the Lua mod. Using registerInput
-- rather than registerHotkey makes the toggle responsive even while a normal
-- game key is held, matching CET's current recommendation.
registerInput("nctc_pocket_guide_toggle", "NCTC: NC Transit Pocket Guide", function(down)
  if not down then return end
  GUIDE.open = not GUIDE.open
  if GUIDE.open then reload_network() end
end)

print("[NCTC Pocket Guide] v1 loaded; bind 'NCTC: NC Transit Pocket Guide' in CET Bindings.")
