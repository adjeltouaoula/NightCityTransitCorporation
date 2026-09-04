-- NCTC developer survey persistence. This file is intentionally packaged
-- only in developer builds; the public mod never requires CET.
local SETTINGS_FILE = "nctc_survey_settings.json"
-- CET's file sandbox permits writes in the mod's own directory, not arbitrary
-- project paths.  A relative path therefore gives us durable, save-independent
-- data that actually works under Vortex/CET.
local DEFAULT_OUTPUT_DIRECTORY = "."
local OUTPUT_DIRECTORY = DEFAULT_OUTPUT_DIRECTORY
local NETWORK_FILE = nil
local DEFAULT_NETWORK_FILE = nil
local BACKUP_FILE = nil
local LOG_FILE = nil
local HUB_RADIUS_METRES = 20.0
local DELETE_RADIUS_METRES = 25.0

local last_event_id = -1
local next_sync_time = 0
local survey_events_initialized = false
local runtime_announced = false


local function load_settings()
  local file = io.open(SETTINGS_FILE, "r")
  if not file then return end
  local content = file:read("*a")
  file:close()
  local ok, settings = pcall(json.decode, content)
  if ok and type(settings) == "table" and type(settings.outputDirectory) == "string" and #settings.outputDirectory > 0 and not string.find(settings.outputDirectory, ":", 1, true) then
    OUTPUT_DIRECTORY = settings.outputDirectory
  end
end

local function log(message)
  if not LOG_FILE then return end
  local file = io.open(LOG_FILE, "a")
  if file then
    file:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. message .. "\n")
    file:close()
  end
end

local function read_json(path, fallback)
  local file = io.open(path, "r")
  if not file then return fallback end
  local content = file:read("*a")
  file:close()
  local ok, decoded = pcall(json.decode, content)
  if ok and type(decoded) == "table" then return decoded end
  return fallback
end

local function write_network(network)
  local encoded = json.encode(network, { indent = true })
  local previous = io.open(NETWORK_FILE, "r")
  if previous then
    local prior = previous:read("*a")
    previous:close()
    local backup = io.open(BACKUP_FILE, "w")
    if backup then backup:write(prior); backup:close() end
  end
  local temporary = io.open(NETWORK_FILE .. ".tmp", "w")
  if not temporary then
    print("[NCTC Survey] Cannot write temporary network file: " .. tostring(NETWORK_FILE .. ".tmp"))
    return false
  end
  temporary:write(encoded)
  temporary:close()
  local verified = io.open(NETWORK_FILE .. ".tmp", "r")
  if not verified then return false end
  local content = verified:read("*a")
  verified:close()
  local destination = io.open(NETWORK_FILE, "w")
  if not destination then
    print("[NCTC Survey] Cannot write network file: " .. tostring(NETWORK_FILE))
    return false
  end
  destination:write(content)
  destination:close()
  print("[NCTC Survey] Network written: " .. tostring(NETWORK_FILE))
  return true
end

local function load_network()
  local network = read_json(NETWORK_FILE, nil)
  if not network then
    network = read_json(DEFAULT_NETWORK_FILE, nil)
    if not network then
      print("[NCTC Survey] Missing default network file: " .. tostring(DEFAULT_NETWORK_FILE))
      return { schemaVersion = 2, revision = 1, stops = {}, captures = {}, hubs = {} }
    end
    write_network(network)
    log("seeded external NCTC network")
  end
  network.stops = network.stops or {}
  network.captures = network.captures or {}
  network.hubs = network.hubs or {}
  network.lineColors = network.lineColors or {}
  -- Migration for networks created before per-line colours existed.
  local legacy_colors = { ["17"] = 0, ["22"] = 1, ["23"] = 2, ["51"] = 3, ["68"] = 4, ["72"] = 5 }
  for line, color in pairs(legacy_colors) do
    if network.lineColors[line] == nil then network.lineColors[line] = color end
  end
  network.revision = network.revision or 1
  return network
end

local function fact(quests, name)
  local ok, value = pcall(function() return quests:GetFact(CName.new(name)) end)
  if ok and type(value) == "number" then return value end
  ok, value = pcall(function() return quests:GetFact(name) end)
  if ok and type(value) == "number" then return value end
  return 0
end

local function set_fact(quests, name, value)
  local ok = pcall(function() quests:SetFact(CName.new(name), value) end)
  if ok then return true end
  ok = pcall(function() quests:SetFact(name, value) end)
  return ok
end

local function vector_from_facts(quests, prefix)
  return {
    x = fact(quests, prefix .. "x") / 1000.0,
    y = fact(quests, prefix .. "y") / 1000.0,
    z = fact(quests, prefix .. "z") / 1000.0,
    yaw = fact(quests, prefix .. "yaw") / 1000.0
  }
end

local function distance_squared(a, b)
  local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
  return x * x + y * y + z * z
end

local function next_sequence(network, line)
  local highest = 0
  for _, stop in ipairs(network.stops) do
    if stop.line == line and (stop.sequence or 0) > highest then highest = stop.sequence end
  end
  return highest + 1
end

local function assign_hub(network, position, event_id)
  network.hubs = network.hubs or {}
  local radius_squared = HUB_RADIUS_METRES * HUB_RADIUS_METRES
  for _, hub in ipairs(network.hubs) do
    if distance_squared(hub.position, position) <= radius_squared then return hub.id end
  end
  local id = "hub-" .. tostring(event_id)
  table.insert(network.hubs, { id = id, position = position })
  return id
end

local function add_stop(network, stop, event_id)
  stop.sequence = stop.sequence or next_sequence(network, stop.line)
  stop.hubId = assign_hub(network, stop.position, event_id)
  table.insert(network.stops, stop)
end

local function delete_nearest_stop(network, line, position, loc_key)
  if loc_key and loc_key > 0 then
    for index, stop in ipairs(network.stops) do
      if stop.line == line and stop.locKey == loc_key then
        local removed = table.remove(network.stops, index)
        local used = false
        for _, remaining in ipairs(network.stops) do
          if remaining.hubId == removed.hubId then used = true; break end
        end
        if not used then
          for hub_index, hub in ipairs(network.hubs or {}) do
            if hub.id == removed.hubId then table.remove(network.hubs, hub_index); break end
          end
        end
        return true
      end
    end
  end
  local nearest, nearest_distance_squared = nil, DELETE_RADIUS_METRES * DELETE_RADIUS_METRES
  for index, stop in ipairs(network.stops) do
    if stop.line == line then
      local distance = distance_squared(stop.position, position)
      if distance <= nearest_distance_squared then
        nearest, nearest_distance_squared = index, distance
      end
    end
  end
  if not nearest then return false end
  local removed = table.remove(network.stops, nearest)
  local used = false
  for _, stop in ipairs(network.stops) do
    if stop.hubId == removed.hubId then used = true; break end
  end
  if not used then
    for index, hub in ipairs(network.hubs or {}) do
      if hub.id == removed.hubId then table.remove(network.hubs, index); break end
    end
  end
  return true
end

local function persist_capture(quests, event_id)
  local network = load_network()
  network.lineColors = network.lineColors or {}

  local event_kind = fact(quests, "nctc_survey_event_kind")
  local draft_count = fact(quests, "nctc_draft_line_stop_count")
  local draft_line = fact(quests, "nctc_draft_line_number")
  local kind = "survey"
  if event_kind == 2 and draft_count > 0 then
    local index = draft_count - 1
    local prefix = "nctc_draft_line_" .. tostring(draft_line) .. "_stop_" .. tostring(index) .. "_"
    add_stop(network, {
      eventId = event_id,
      line = draft_line,
      sequence = draft_count,
      anchorType = "fastTravel",
      locKey = fact(quests, prefix .. "loc_key"),
      position = {
        x = fact(quests, prefix .. "x") / 1000.0,
        y = fact(quests, prefix .. "y") / 1000.0,
        z = fact(quests, prefix .. "z") / 1000.0
      }
    }, event_id)
    -- Colour is immutable after the first stop of this draft line: this is a
    -- creation attribute, not an editor for existing services.
    if draft_count == 1 then network.lineColors[tostring(draft_line)] = fact(quests, "nctc_draft_line_color") end
    kind = "stop"
  elseif event_kind == 3 then
    local position = {
      x = fact(quests, "nctc_manual_stop_x") / 1000.0,
      y = fact(quests, "nctc_manual_stop_y") / 1000.0,
      z = fact(quests, "nctc_manual_stop_z") / 1000.0
    }
    add_stop(network, {
      eventId = event_id,
      line = fact(quests, "nctc_manual_stop_line"),
      anchorType = "manual",
      position = position
    }, event_id)
    kind = "manual stop"
  elseif event_kind == 4 then
    local position = {
      x = fact(quests, "nctc_delete_stop_x") / 1000.0,
      y = fact(quests, "nctc_delete_stop_y") / 1000.0,
      z = fact(quests, "nctc_delete_stop_z") / 1000.0
    }
    local deleted = delete_nearest_stop(network, fact(quests, "nctc_delete_stop_line"), position, fact(quests, "nctc_delete_stop_loc_key"))
    kind = deleted and "deleted stop" or "no stop deleted"
  else
    table.insert(network.captures, {
      eventId = event_id,
      line = fact(quests, "nctc_survey_line"),
      passage = fact(quests, "nctc_survey_imported_passage"),
      spawn = vector_from_facts(quests, "nctc_survey_spawn_"),
      approach = vector_from_facts(quests, "nctc_survey_approach_"),
      berth = vector_from_facts(quests, "nctc_survey_berth_")
    })
  end
  network.lastEventId = event_id
  network.revision = (network.revision or 0) + 1
  if write_network(network) then log("saved " .. kind .. " event " .. tostring(event_id)) end
end

local function publish_network(quests, network)
  local count = math.min(#(network.stops or {}), 160)
  for index = 1, count do
    local stop = network.stops[index]
    local prefix = "nctc_external_stop_" .. tostring(index - 1) .. "_"
    set_fact(quests, prefix .. "line", stop.line or 0)
    set_fact(quests, prefix .. "loc_key", stop.locKey or 0)
    local position = stop.position or {}
    set_fact(quests, prefix .. "x", math.floor((position.x or 0) * 1000))
    set_fact(quests, prefix .. "y", math.floor((position.y or 0) * 1000))
    set_fact(quests, prefix .. "z", math.floor((position.z or 0) * 1000))
  end
  for line, color in pairs(network.lineColors or {}) do
    set_fact(quests, "nctc_external_line_" .. tostring(line) .. "_color", color)
  end
  set_fact(quests, "nctc_external_network_stop_count", count)
  set_fact(quests, "nctc_external_network_ready", 1)
  set_fact(quests, "nctc_external_network_revision", network.revision or 1)
end

-- Redscript deliberately cannot read files. CET restores the latest surveyed
-- L17 passage into quest facts after every save load, so the bus consumes the
-- same external record whether the player reloads now or next week.
local function apply_capture(quests, capture)
  local function apply_vector(prefix, point)
    if type(point) ~= "table" then return end
    set_fact(quests, prefix .. "x", math.floor((point.x or 0) * 1000))
    set_fact(quests, prefix .. "y", math.floor((point.y or 0) * 1000))
    set_fact(quests, prefix .. "z", math.floor((point.z or 0) * 1000))
    set_fact(quests, prefix .. "yaw", math.floor((point.yaw or 0) * 1000))
    set_fact(quests, prefix .. "valid", 1)
  end
  set_fact(quests, "nctc_survey_imported_passage", capture.passage or 0)
  apply_vector("nctc_survey_spawn_", capture.spawn)
  apply_vector("nctc_survey_approach_", capture.approach)
  apply_vector("nctc_survey_berth_", capture.berth)
end

local function publish_capture(quests, capture)
  local passage = capture.passage or 0
  local function publish_vector(kind, point)
    if type(point) ~= "table" then return end
    local prefix = "nctc_external_capture_" .. tostring(passage) .. "_" .. kind .. "_"
    set_fact(quests, prefix .. "x", math.floor((point.x or 0) * 1000))
    set_fact(quests, prefix .. "y", math.floor((point.y or 0) * 1000))
    set_fact(quests, prefix .. "z", math.floor((point.z or 0) * 1000))
    set_fact(quests, prefix .. "yaw", math.floor((point.yaw or 0) * 1000))
    set_fact(quests, prefix .. "valid", 1)
  end
  set_fact(quests, "nctc_external_capture_" .. tostring(passage) .. "_line", capture.line or 0)
  publish_vector("spawn", capture.spawn)
  publish_vector("approach", capture.approach)
  publish_vector("berth", capture.berth)
end

local function synchronize_external_survey(quests)
  local network = load_network()
  local revision = network.revision or 1
  if fact(quests, "nctc_external_network_revision") ~= revision then publish_network(quests, network) end
  -- Every passage receives its own fact namespace. Future enabled routes can
  -- consume their capture directly; no information is thrown away when a
  -- different line is surveyed afterwards.
  local legacy_chosen = nil
  for _, capture in ipairs(network.captures or {}) do
    publish_capture(quests, capture)
    if capture.line == 0 and capture.passage == 0 and (not legacy_chosen or (capture.eventId or 0) > (legacy_chosen.eventId or 0)) then
      legacy_chosen = capture
    end
  end
  if legacy_chosen and fact(quests, "nctc_external_survey_revision") ~= revision then
    apply_capture(quests, legacy_chosen)
    log("restored surveyed passage from external revision " .. tostring(revision))
  end
  set_fact(quests, "nctc_external_survey_revision", revision)
end

registerForEvent("onUpdate", function()
  local quests = Game.GetQuestsSystem()
  if not quests then return end
  if not runtime_announced then
    runtime_announced = true
    print("[NCTC Survey] Runtime active; external path: " .. tostring(NETWORK_FILE))
  end
  local event_id = fact(quests, "nctc_survey_event_id")
  -- A save load restores the old event counter. Treat that first observed
  -- value as a baseline, never as a brand-new capture that could overwrite
  -- the external network with stale save data.
  if not survey_events_initialized then
    survey_events_initialized = true
    last_event_id = event_id
  elseif event_id > 0 and event_id ~= last_event_id then
    last_event_id = event_id
    persist_capture(quests, event_id)
  end
  local now = os.clock()
  if now >= next_sync_time then
    next_sync_time = now + 1.0
    synchronize_external_survey(quests)
  end
end)

registerForEvent("onInit", function()
  load_settings()
  NETWORK_FILE = OUTPUT_DIRECTORY .. "/nctc_network.json"
  DEFAULT_NETWORK_FILE = OUTPUT_DIRECTORY .. "/nctc_network.default.json"
  BACKUP_FILE = OUTPUT_DIRECTORY .. "/nctc_network.previous.json"
  LOG_FILE = OUTPUT_DIRECTORY .. "/nctc_survey.log"
  print("[NCTC Survey] Initialized; external path: " .. tostring(NETWORK_FILE))
  log("NCTC survey persistence loaded")
end)
