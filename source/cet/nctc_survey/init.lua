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
-- Two stops on the same service this close are an authoring mistake, not a
-- transfer: transfers only exist between different lines.
local SAME_LINE_DUPLICATE_RADIUS_METRES = 10.0
-- Re-recording the same pass-through point updates it instead of creating a
-- second handoff a few metres later.
local PASSAGE_DUPLICATE_RADIUS_METRES = 4.0

local last_event_id = -1
local next_sync_time = 0
local survey_events_initialized = false
local runtime_announced = false
local runtime_session_id = 0
-- The previous session-token comparison could fail to round-trip through
-- quest facts on some saves. That made the full external network publish on
-- every second, temporarily clearing berth_valid while a bus was trying to
-- depart. Keep an in-memory revision acknowledgement as well: a save load
-- still has an older revision in its facts and therefore repopulates once,
-- but an unchanged live session does not rewrite route data beneath the AI.
local last_published_network_revision = -1
local last_dispatch_log_id = 0
local last_loop_log_id = 0
local last_native_command_event_id = 0
local last_service_crime_suppressed_id = 0
local last_service_calm_reaction_id = 0
local last_sequence_probe_id = 0
local last_profile_probe_id = 0
local last_build_revision = -1
local last_stale_drive_callback_id = 0
local fact
local deduplicate_same_line_stops
local normalize_captures
local normalize_passages
local remove_orphan_captures
local ensure_stop_ids
local join_or_create_hub


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
  print("[NCTC Route] " .. message)
  if not LOG_FILE then return end
  local file = io.open(LOG_FILE, "a")
  if file then
    file:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. message .. "\n")
    file:close()
  end
end

local function log_sequence_probe(quests)
  local id = fact(quests, "nctc_dev_sequence_probe_id")
  if id < last_sequence_probe_id then last_sequence_probe_id = id - 1 end
  if id <= last_sequence_probe_id then return end
  last_sequence_probe_id = id
  local states = {
    [1] = "network not ready / invalid line",
    [2] = "current stop ID absent from published line",
    [3] = "successor selected by published service order",
    [4] = "candidate array entry had no stop ID",
    [5] = "wrapped to first line entry",
    [6] = "no stops published for requested line"
  }
  log("sequence probe #" .. tostring(id)
    .. ": " .. (states[fact(quests, "nctc_dev_sequence_probe_code")] or "unknown")
    .. " | L" .. tostring(fact(quests, "nctc_dev_sequence_probe_line"))
    .. " current=" .. tostring(fact(quests, "nctc_dev_sequence_probe_current_id"))
    .. " index=" .. tostring(fact(quests, "nctc_dev_sequence_probe_current_sequence"))
    .. " next=" .. tostring(fact(quests, "nctc_dev_sequence_probe_next_id"))
    .. " index=" .. tostring(fact(quests, "nctc_dev_sequence_probe_next_sequence"))
    .. " count=" .. tostring(fact(quests, "nctc_dev_sequence_probe_count")))
end

local function log_profile_probe(quests)
  local id = fact(quests, "nctc_dev_profile_probe_id")
  if id < last_profile_probe_id then last_profile_probe_id = id - 1 end
  if id <= last_profile_probe_id then return end
  last_profile_probe_id = id
  log("profile probe #" .. tostring(id)
    .. ": stopId=" .. tostring(fact(quests, "nctc_dev_profile_probe_stop_id"))
    .. " spawnValid=" .. tostring(fact(quests, "nctc_dev_profile_probe_spawn_valid"))
    .. " approachValid=" .. tostring(fact(quests, "nctc_dev_profile_probe_approach_valid"))
    .. " berthValid=" .. tostring(fact(quests, "nctc_dev_profile_probe_berth_valid"))
    .. string.format(" | spawn=(%.3f, %.3f) berth=(%.3f, %.3f)",
      fact(quests, "nctc_dev_profile_probe_spawn_x_mm") / 1000.0,
      fact(quests, "nctc_dev_profile_probe_spawn_y_mm") / 1000.0,
      fact(quests, "nctc_dev_profile_probe_berth_x_mm") / 1000.0,
      fact(quests, "nctc_dev_profile_probe_berth_y_mm") / 1000.0))
end

local function round3(value)
  if value >= 0 then return math.floor(value * 1000.0 + 0.5) / 1000.0 end
  return math.ceil(value * 1000.0 - 0.5) / 1000.0
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
  network.passages = network.passages or {}
  network.lineColors = network.lineColors or {}
  local stop_ids_assigned = ensure_stop_ids(network)
  local capture_ids_assigned = false
  for _, capture in ipairs(network.captures) do
    if not capture.stopId or capture.stopId < 1 then
      local ordinal = 0
      for _, stop in ipairs(network.stops) do
        if stop.line == capture.line then
          ordinal = ordinal + 1
          if ordinal == capture.stopIndex then
            capture.stopId = stop.id
            capture_ids_assigned = true
            break
          end
        end
      end
    end
  end
  local duplicates_merged = deduplicate_same_line_stops(network)
  local passages_normalized = normalize_passages(network)
  local orphan_captures_removed = remove_orphan_captures(network)
  local captures_normalized = normalize_captures(network)
  local colors_migrated = false
  -- Migration for networks created before per-line colours existed.
  local legacy_colors = { ["17"] = 0, ["22"] = 1, ["23"] = 2, ["51"] = 3, ["68"] = 4, ["72"] = 5 }
  for line, color in pairs(legacy_colors) do
    if network.lineColors[line] == nil then
      network.lineColors[line] = color
      colors_migrated = true
    end
  end
  network.revision = network.revision or 1
  if colors_migrated or duplicates_merged or passages_normalized or orphan_captures_removed or captures_normalized or stop_ids_assigned or capture_ids_assigned then
    network.revision = network.revision + 1
    write_network(network)
    if colors_migrated then log("migrated legacy line colours into active network") end
    if duplicates_merged then log("normalized same-line duplicate stops in active network") end
    if passages_normalized then log("merged near-identical duplicate passage points in active network") end
    if captures_normalized then log("merged legacy duplicate survey captures") end
    if orphan_captures_removed then log("removed survey captures belonging to deleted stops") end
    if stop_ids_assigned then log("assigned stable IDs to survey stops") end
    if capture_ids_assigned then log("attached legacy survey captures to stable stop IDs") end
  end
  return network
end

fact = function(quests, name)
  -- Dynamic NCTC names (for example nctc_external_stop_12_sequence) must
  -- use the String quest-fact API. The generic GetFact overload can return
  -- a non-fact numeric value for those dynamic names without throwing.
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

-- CET exposes both String and CName overloads for quest facts. Keep this
-- separate diagnostic read so we can prove which overload returns the value
-- actually stored by the game before changing synchronization behavior.
local function fact_as_string(quests, name)
  local ok, value = pcall(function() return quests:GetFactStr(name) end)
  value = tonumber(value)
  if ok and value ~= nil then return math.floor(value) end
  return 0
end

-- Separate from the quest-system object calls above: CET also exposes the
-- engine's direct convenience getter. This is diagnostic-only. We need to
-- establish whether it returns the stored integer or the same unexpected
-- value before changing the synchronization contract.
local function game_fact(name)
  local ok, value = pcall(function() return Game.GetFact(name) end)
  if ok and type(value) == "number" then return value end
  return 0
end

local function set_fact(quests, name, value)
  value = math.floor(tonumber(value) or 0)
  local ok = pcall(function() quests:SetFactStr(name, value) end)
  if ok then return true end
  ok = pcall(function() quests:SetFact(CName.new(name), value) end)
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

normalize_passages = function(network)
  local source = network.passages or {}
  local merged = {}
  local changed = false
  local radius_squared = PASSAGE_DUPLICATE_RADIUS_METRES * PASSAGE_DUPLICATE_RADIUS_METRES
  for _, passage in ipairs(source) do
    local duplicate_index = nil
    if passage.position then
      for index, existing in ipairs(merged) do
        if existing.line == passage.line
          and existing.afterStopId == passage.afterStopId
          and existing.position
          and distance_squared(existing.position, passage.position) <= radius_squared then
          duplicate_index = index
          break
        end
      end
    end
    if duplicate_index then
      merged[duplicate_index] = passage
      changed = true
    else
      table.insert(merged, passage)
    end
  end
  if changed then network.passages = merged end
  return changed
end

local function next_sequence(network, line)
  local highest = 0
  for _, stop in ipairs(network.stops) do
    if stop.line == line and (stop.sequence or 0) > highest then highest = stop.sequence end
  end
  return highest + 1
end

ensure_stop_ids = function(network)
  local next_id = network.nextStopId or 1
  local changed = false
  for _, stop in ipairs(network.stops or {}) do
    if not stop.id or stop.id < 1 then
      stop.id = next_id
      next_id = next_id + 1
      changed = true
    elseif stop.id >= next_id then
      next_id = stop.id + 1
    end
  end
  if network.nextStopId ~= next_id then network.nextStopId = next_id; changed = true end
  return changed
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
  network.nextStopId = network.nextStopId or 1
  stop.id = network.nextStopId
  network.nextStopId = network.nextStopId + 1
  stop.sequence = stop.sequence or next_sequence(network, stop.line)
  local duplicate_radius_squared = SAME_LINE_DUPLICATE_RADIUS_METRES * SAME_LINE_DUPLICATE_RADIUS_METRES
  for _, existing in ipairs(network.stops) do
    if existing.line == stop.line and existing.position and stop.position
      and distance_squared(existing.position, stop.position) <= duplicate_radius_squared then
      log("ignored duplicate stop on line " .. tostring(stop.line))
      return false
    end
  end
  table.insert(network.stops, stop)
  join_or_create_hub(network, stop, event_id)
  return true
end

local function line_has_stop(network, line)
  for _, stop in ipairs(network.stops or {}) do
    if stop.line == line then return true end
  end
  return false
end

local function line_stop_index(network, global_index, line)
  local ordinal = 0
  for index, stop in ipairs(network.stops) do
    if stop.line == line then ordinal = ordinal + 1 end
    if index == global_index then return ordinal end
  end
  return 0
end

-- Captures are currently keyed by the user-facing ordinal in a line. When a
-- duplicate is removed, move its measurements to the earlier surviving stop
-- and shift later ordinals so no recorded spawn/berth becomes orphaned.
local function remap_captures_after_duplicate(network, line, kept_index, removed_index)
  for _, capture in ipairs(network.captures or {}) do
    if capture.line == line and capture.stopIndex then
      if capture.stopIndex == removed_index then
        capture.stopIndex = kept_index
      elseif capture.stopIndex > removed_index then
        capture.stopIndex = capture.stopIndex - 1
      end
    end
  end
end

local function vector_has_position(vector)
  return vector and ((vector.x or 0) ~= 0 or (vector.y or 0) ~= 0 or (vector.z or 0) ~= 0)
end

normalize_captures = function(network)
  local unique, ordered, changed = {}, {}, false
  for _, capture in ipairs(network.captures or {}) do
    -- stopIndex is only a mutable editor ordinal.  Deleting a stop and then
    -- adding another can give two distinct stops the same ordinal, which used
    -- to merge their captures and silently transplant a spawn/berth onto the
    -- wrong stop.  Stable stopId is the authoritative identity.  The ordinal
    -- remains a compatibility fallback for old networks that predate IDs.
    local key = capture.stopId and ("id:" .. tostring(capture.stopId))
      or ("legacy:" .. tostring(capture.line or 0) .. ":" .. tostring(capture.stopIndex or 0))
    local saved = unique[key]
    if not saved then
      saved = capture
      unique[key] = saved
      table.insert(ordered, saved)
    else
      -- Legacy versions wrote a complete snapshot for every key press. Keep
      -- the latest non-empty value for each point while reducing it to one
      -- record, so no useful spawn or berth is thrown away.
      if vector_has_position(capture.spawn) then saved.spawn = capture.spawn end
      if vector_has_position(capture.approach) then saved.approach = capture.approach end
      if vector_has_position(capture.berth) then saved.berth = capture.berth end
      saved.eventId = capture.eventId or saved.eventId
      saved.stopSequence = capture.stopSequence or saved.stopSequence
      saved.stopLocKey = capture.stopLocKey or saved.stopLocKey
      saved.stopName = capture.stopName or saved.stopName
      changed = true
    end
  end
  if changed then network.captures = ordered end
  return changed
end

local function capture_score(network, line, stop_index)
  local score = 0
  for _, capture in ipairs(network.captures or {}) do
    if capture.line == line and capture.stopIndex == stop_index then
      local spawn = vector_has_position(capture.spawn)
      local berth = vector_has_position(capture.berth)
      if spawn and berth then return 2 end
      if spawn or berth then score = 1 end
    end
  end
  return score
end

deduplicate_same_line_stops = function(network)
  local changed = false
  local radius_squared = SAME_LINE_DUPLICATE_RADIUS_METRES * SAME_LINE_DUPLICATE_RADIUS_METRES
  local index = 1
  while index <= #network.stops do
    local kept = network.stops[index]
    local candidate = index + 1
    while candidate <= #network.stops do
      local other = network.stops[candidate]
      if kept.line == other.line and kept.position and other.position
        and distance_squared(kept.position, other.position) <= radius_squared then
        local kept_ordinal = line_stop_index(network, index, kept.line)
        local removed_ordinal = line_stop_index(network, candidate, kept.line)
        -- Prefer the stop for which the survey already contains both end
        -- points. This matters when two nearby manual placements differ by a
        -- few metres: we retain the coordinate that has been actually driven.
        if capture_score(network, kept.line, removed_ordinal) > capture_score(network, kept.line, kept_ordinal) then
          network.stops[index] = other
          kept = other
        end
        remap_captures_after_duplicate(network, kept.line, kept_ordinal, removed_ordinal)
        table.remove(network.stops, candidate)
        changed = true
        log("merged duplicate stop on line " .. tostring(kept.line)
          .. " (stop " .. tostring(removed_ordinal) .. " into " .. tostring(kept_ordinal) .. ")")
      else
        candidate = candidate + 1
      end
    end
    index = index + 1
  end
  return changed
end

local function delete_selected_stop(network, line, selected_index)
  local matches = {}
  for index, stop in ipairs(network.stops or {}) do
    if stop.line == line then
      table.insert(matches, { arrayIndex = index, stop = stop })
    end
  end
  table.sort(matches, function(a, b)
    local a_sequence, b_sequence = tonumber(a.stop.sequence) or 0, tonumber(b.stop.sequence) or 0
    if a_sequence ~= b_sequence then return a_sequence < b_sequence end
    return (tonumber(a.stop.id) or 0) < (tonumber(b.stop.id) or 0)
  end)
  local selected = matches[selected_index]
  if not selected then return false, "selected stop unavailable" end
  local removed = table.remove(network.stops, selected.arrayIndex)
  for index = #(network.captures or {}), 1, -1 do
    if network.captures[index].stopId == removed.id then table.remove(network.captures, index) end
  end
  local used = false
  for _, stop in ipairs(network.stops) do
    if stop.hubId == removed.hubId then used = true; break end
  end
  if not used then
    for index, hub in ipairs(network.hubs or {}) do
      if hub.id == removed.hubId then table.remove(network.hubs, index); break end
    end
  end
  return true, "line " .. tostring(line) .. " stop " .. tostring(selected_index)
end

remove_orphan_captures = function(network)
  local known, changed = {}, false
  for _, stop in ipairs(network.stops or {}) do known[stop.id] = true end
  for index = #(network.captures or {}), 1, -1 do
    local capture = network.captures[index]
    if capture.stopId and capture.stopId > 0 and not known[capture.stopId] then
      log("removed orphan capture for deleted stop ID " .. tostring(capture.stopId))
      table.remove(network.captures, index)
      changed = true
    end
  end
  return changed
end

local function selected_stop(network, line, stop_index)
  local matches = {}
  for _, stop in ipairs(network.stops or {}) do
    if stop.line == line then table.insert(matches, stop) end
  end
  -- IMPORTANT: the runtime publishes/consumes stops in authored `sequence`
  -- order, not in physical JSON append order.  The developer editor must use
  -- that exact same ordering or "after stop N" can silently bind a passage
  -- to a different stable stop ID than the bus will use for that route leg.
  table.sort(matches, function(a, b)
    local a_sequence, b_sequence = tonumber(a.sequence) or 0, tonumber(b.sequence) or 0
    if a_sequence ~= b_sequence then return a_sequence < b_sequence end
    return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
  end)
  return matches[stop_index], #matches
end

local function copy_position(position)
  return { x = position.x, y = position.y, z = position.z }
end

local function find_hub(network, hub_id)
  for _, hub in ipairs(network.hubs or {}) do
    if hub.id == hub_id then return hub end
  end
  return nil
end

-- Hubs are created only by a second stop from a different line. The first
-- existing stop is the immutable reference; joining stops inherit its map and
-- call position, never its driving captures.
join_or_create_hub = function(network, stop, event_id)
  if not stop.position then return end
  local radius_squared = HUB_RADIUS_METRES * HUB_RADIUS_METRES
  for _, existing in ipairs(network.stops or {}) do
    if existing ~= stop and existing.line ~= stop.line and existing.position
      and distance_squared(existing.position, stop.position) <= radius_squared then
      local hub = existing.hubId and find_hub(network, existing.hubId) or nil
      if not hub then
        hub = { id = "hub-" .. tostring(event_id), position = copy_position(existing.position), referenceStopId = existing.id }
        network.hubs = network.hubs or {}
        table.insert(network.hubs, hub)
        existing.hubId = hub.id
      end
      stop.hubId = hub.id
      stop.position = copy_position(hub.position)
      for _, member in ipairs(network.stops or {}) do
        if member.hubId == hub.id then member.position = copy_position(hub.position) end
      end
      return
    end
  end
  stop.hubId = nil
end

-- Replacement preserves identity, array order, and every driving capture.
-- Only the stop's map/call position and optional display anchor change.
local function replace_selected_stop(network, line, stop_index, position, loc_key, event_id)
  local target, count = selected_stop(network, line, stop_index)
  if not target then return false, count end
  target.position = position
  if loc_key and loc_key > 0 then
    target.locKey = loc_key
    target.anchorType = "travelAnchor"
  else
    target.locKey = nil
    target.anchorType = "manual"
  end
  local old_hub = target.hubId and find_hub(network, target.hubId) or nil
  if old_hub and old_hub.referenceStopId == target.id then
    -- The original creator remains the reference forever. Moving it moves the
    -- whole hub, while retaining every member's independent driving profile.
    old_hub.position = copy_position(position)
    for _, member in ipairs(network.stops or {}) do
      if member.hubId == old_hub.id then member.position = copy_position(old_hub.position) end
    end
  elseif old_hub then
    target.hubId = nil
    local members = 0
    for _, member in ipairs(network.stops or {}) do
      if member.hubId == old_hub.id then members = members + 1 end
    end
    if members < 2 then
      for _, member in ipairs(network.stops or {}) do
        if member.hubId == old_hub.id then member.hubId = nil end
      end
      for index, hub in ipairs(network.hubs or {}) do
        if hub.id == old_hub.id then table.remove(network.hubs, index); break end
      end
    end
    join_or_create_hub(network, target, event_id)
  else
    join_or_create_hub(network, target, event_id)
  end
  return true, count
end

-- A passage is a traffic-only point on the leg after a stop. It must never
-- become an NCTC stop, mappin, hub, or service/capture profile.
local function add_passage_after_selected(network, line, after_index, position, yaw, event_id)
  local target, count = selected_stop(network, line, after_index)
  if not target then return false, count end
  network.passages = network.passages or {}

  local radius_squared = PASSAGE_DUPLICATE_RADIUS_METRES * PASSAGE_DUPLICATE_RADIUS_METRES
  for _, passage in ipairs(network.passages) do
    if passage.line == line
      and passage.afterStopId == target.id
      and passage.position
      and distance_squared(passage.position, position) <= radius_squared then
      passage.eventId = event_id
      passage.afterSequence = target.sequence or after_index
      passage.position = copy_position(position)
      passage.yaw = yaw
      return true, count
    end
  end

  table.insert(network.passages, {
    id = "passage-" .. tostring(event_id),
    eventId = event_id,
    line = line,
    afterStopId = target.id,
    -- Keep the human-readable service order beside the stable ID. Runtime
    -- routing still keys on afterStopId, but this makes authoring mistakes
    -- obvious and gives future migrations enough information to repair them.
    afterSequence = target.sequence or after_index,
    position = copy_position(position),
    yaw = yaw
  })
  return true, count
end

local function delete_nearest_passage(network, line, position)
  local nearest, nearest_distance_squared = nil, 30.0 * 30.0
  for index, passage in ipairs(network.passages or {}) do
    if passage.line == line and passage.position then
      local distance = distance_squared(passage.position, position)
      if distance <= nearest_distance_squared then nearest, nearest_distance_squared = index, distance end
    end
  end
  if not nearest then return false end
  table.remove(network.passages, nearest)
  return true
end

local function find_capture(network, stop_id)
  for index = #(network.captures or {}), 1, -1 do
    local capture = network.captures[index]
    if capture.stopId == stop_id then return capture end
  end
  return nil
end

local function update_capture_point(capture, point, value)
  if point == 1 then
    capture.spawn = value
    return "spawn"
  elseif point == 2 then
    capture.approach = value
    return "approach"
  end
  capture.berth = value
  return "berth"
end

local function persist_capture(quests, event_id)
  local network = load_network()
  network.lineColors = network.lineColors or {}

  local event_kind = fact(quests, "nctc_survey_event_kind")
  local draft_count = fact(quests, "nctc_draft_line_stop_count")
  local draft_line = fact(quests, "nctc_draft_line_number")
  local kind = "survey"
  -- Direct CET capture owns all survey points in this experimental branch.
  -- Saved quest facts from old builds may still contain event kind 1; never
  -- let them overwrite a direct JSON capture after a load.
  if event_kind == 1 then
    log("ignored legacy survey-point event " .. tostring(event_id))
    return
  end
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
    local loc_key = fact(quests, "nctc_manual_stop_loc_key")
    local line = fact(quests, "nctc_manual_stop_line")
    local is_new_line = not line_has_stop(network, line)
    add_stop(network, {
      eventId = event_id,
      line = line,
      -- The coordinate remains manual/roadside even when an anchor lends its
      -- name. The type only documents that the display LocKey was linked.
      anchorType = loc_key > 0 and "travelAnchor" or "manual",
      locKey = loc_key > 0 and loc_key or nil,
      position = position
    }, event_id)
    if is_new_line then network.lineColors[tostring(line)] = fact(quests, "nctc_manual_stop_color") end
    kind = "manual stop"
  elseif event_kind == 9 then
    local line = fact(quests, "nctc_terminal_stop_line")
    local is_new_line = not line_has_stop(network, line)
    add_stop(network, {
      eventId = event_id, line = line, anchorType = "fastTravel",
      locKey = fact(quests, "nctc_terminal_stop_loc_key"),
      position = {
        x = fact(quests, "nctc_terminal_stop_x") / 1000.0,
        y = fact(quests, "nctc_terminal_stop_y") / 1000.0,
        z = fact(quests, "nctc_terminal_stop_z") / 1000.0
      }
    }, event_id)
    if is_new_line then network.lineColors[tostring(line)] = fact(quests, "nctc_terminal_stop_color") end
    kind = "terminal stop"
  elseif event_kind == 4 then
    local deleted, detail = delete_selected_stop(network,
      fact(quests, "nctc_delete_stop_line"), fact(quests, "nctc_delete_stop_index"))
    kind = deleted and "deleted " .. detail or "no stop deleted: " .. detail
  elseif event_kind == 6 then
    local position = {
      x = fact(quests, "nctc_replace_stop_x") / 1000.0,
      y = fact(quests, "nctc_replace_stop_y") / 1000.0,
      z = fact(quests, "nctc_replace_stop_z") / 1000.0
    }
    local replaced, count = replace_selected_stop(network,
      fact(quests, "nctc_replace_stop_line"),
      fact(quests, "nctc_replace_stop_index"),
      position,
      fact(quests, "nctc_replace_stop_loc_key"),
      event_id)
    if not replaced then
      log("rejected selected-stop move " .. tostring(event_id) .. ": selected stop unavailable")
      return
    end
    local linked_loc_key = fact(quests, "nctc_replace_stop_loc_key")
    kind = "moved selected stop " .. tostring(fact(quests, "nctc_replace_stop_index")) .. "/" .. tostring(count)
      .. " anchorLocKey=" .. tostring(linked_loc_key)
  elseif event_kind == 7 then
    local position = {
      x = fact(quests, "nctc_passage_x") / 1000.0,
      y = fact(quests, "nctc_passage_y") / 1000.0,
      z = fact(quests, "nctc_passage_z") / 1000.0
    }
    local inserted, count = add_passage_after_selected(network,
      fact(quests, "nctc_passage_line"),
      fact(quests, "nctc_passage_after_index"),
      position,
      fact(quests, "nctc_passage_yaw") / 1000.0,
      event_id)
    if not inserted then
      log("rejected passage point " .. tostring(event_id) .. ": selected stop unavailable")
      return
    end
    kind = "passage point after " .. tostring(fact(quests, "nctc_passage_after_index")) .. "/" .. tostring(count)
  elseif event_kind == 8 then
    local position = {
      x = fact(quests, "nctc_delete_passage_x") / 1000.0,
      y = fact(quests, "nctc_delete_passage_y") / 1000.0,
      z = fact(quests, "nctc_delete_passage_z") / 1000.0
    }
    local deleted = delete_nearest_passage(network, fact(quests, "nctc_delete_passage_line"), position)
    kind = deleted and "deleted passage point" or "no passage point deleted"
  else
    local capture_line = fact(quests, "nctc_survey_capture_line")
    local capture_stop_index = fact(quests, "nctc_survey_capture_stop_index")
    local target, count = selected_stop(network, capture_line, capture_stop_index)
    if not target then
      log("rejected survey event " .. tostring(event_id) .. ": line " .. tostring(capture_line) .. " stop " .. tostring(capture_stop_index) .. " unavailable")
      return
    end
    -- A stop has one editable survey record. Re-recording a point updates
    -- only that point and retains the other two measurements.
    local capture = find_capture(network, target.id)
    if not capture then
      capture = {
        line = capture_line,
        stopId = target.id,
        stopIndex = capture_stop_index,
        spawn = {}, approach = {}, berth = {}
      }
      table.insert(network.captures, capture)
    end
    capture.eventId = event_id
    capture.stopSequence = target.sequence
    capture.stopId = target.id
    capture.stopLocKey = target.locKey
    capture.stopName = target.name
    local point = fact(quests, "nctc_survey_capture_point")
    local point_prefix = point == 1 and "nctc_survey_spawn_"
      or (point == 2 and "nctc_survey_approach_" or "nctc_survey_berth_")
    local point_name = update_capture_point(capture, point, vector_from_facts(quests, point_prefix))
    kind = "survey " .. point_name .. " L" .. tostring(capture_line) .. " stop " .. tostring(capture_stop_index) .. "/" .. tostring(count)
  end
  network.lastEventId = event_id
  network.revision = (network.revision or 0) + 1
  if write_network(network) then
    set_fact(quests, "nctc_survey_write_ack_event_id", event_id)
    log("saved " .. kind .. " event " .. tostring(event_id))
  end
end

-- Direct CET survey capture. Unlike the legacy redscript bridge above, the
-- position never lives in quest facts and therefore cannot be restored from a
-- save and replayed over the external JSON.
local function capture_directly(kind)
  local quests = Game.GetQuestsSystem()
  local player = Game.GetPlayer()
  if not quests or not player or fact(quests, "nctc_survey_developer_mode") ~= 1 then return end
  local line = fact(quests, "nctc_survey_selected_line")
  local stop_index = fact(quests, "nctc_survey_selected_stop_index")
  local network = load_network()
  local target, count = selected_stop(network, line, stop_index)
  if not target then
    log("direct " .. kind .. " rejected: line " .. tostring(line) .. " stop " .. tostring(stop_index) .. " unavailable")
    return
  end
  local position = player:GetWorldPosition()
  if not position then return end
  local capture = find_capture(network, target.id)
  if not capture then
    capture = { line = line, stopId = target.id, stopIndex = stop_index, spawn = {}, approach = {}, berth = {} }
    table.insert(network.captures, capture)
  end
  capture.line = line
  capture.stopId = target.id
  capture.stopIndex = stop_index
  capture.stopSequence = target.sequence
  capture.stopLocKey = target.locKey
  capture.stopName = target.name
  capture.eventId = (capture.eventId or 0) + 1
  local point = { x = round3(position.x), y = round3(position.y), z = round3(position.z), yaw = round3(player:GetWorldYaw()) }
  update_capture_point(capture, kind == "spawn" and 1 or (kind == "approach" and 2 or 3), point)
  network.revision = (network.revision or 0) + 1
  if write_network(network) then
    local point_code = kind == "spawn" and 1 or (kind == "approach" and 2 or 3)
    set_fact(quests, "nctc_survey_direct_notice_point", point_code)
    set_fact(quests, "nctc_survey_direct_notice_id", fact(quests, "nctc_survey_direct_notice_id") + 1)
    log("direct saved " .. kind .. " L" .. tostring(line) .. " stop " .. tostring(stop_index) .. "/" .. tostring(count)
      .. " at (" .. tostring(point.x) .. ", " .. tostring(point.y) .. ", " .. tostring(point.z) .. ")")
  end
end

local function publish_network(quests, network)
  -- The physical JSON array is append-order: moving a stop only changes its
  -- authored `sequence`.  Redscript consumes the published array as the
  -- route order, so publish a sorted copy rather than leaking append-order
  -- into service navigation.
  local ordered_stops = {}
  for _, stop in ipairs(network.stops or {}) do table.insert(ordered_stops, stop) end
  table.sort(ordered_stops, function(a, b)
    local a_line, b_line = tonumber(a.line) or 0, tonumber(b.line) or 0
    if a_line ~= b_line then return a_line < b_line end
    local a_sequence, b_sequence = tonumber(a.sequence) or 0, tonumber(b.sequence) or 0
    if a_sequence ~= b_sequence then return a_sequence < b_sequence end
    return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
  end)
  local count = math.min(#ordered_stops, 160)
  for index = 1, count do
    local stop = ordered_stops[index]
    local prefix = "nctc_external_stop_" .. tostring(index - 1) .. "_"
    set_fact(quests, prefix .. "line", stop.line or 0)
    set_fact(quests, prefix .. "id", stop.id or 0)
    set_fact(quests, prefix .. "sequence", stop.sequence or index)
    set_fact(quests, prefix .. "loc_key", stop.locKey or 0)
    local position = stop.position or {}
    set_fact(quests, prefix .. "x", math.floor((position.x or 0) * 1000))
    set_fact(quests, prefix .. "y", math.floor((position.y or 0) * 1000))
    set_fact(quests, prefix .. "z", math.floor((position.z or 0) * 1000))
  end
  for line, color in pairs(network.lineColors or {}) do
    set_fact(quests, "nctc_external_line_" .. tostring(line) .. "_color", color)
  end
  local passage_count = math.min(#(network.passages or {}), 160)
  for index = 1, passage_count do
    local passage = network.passages[index]
    local prefix = "nctc_external_passage_" .. tostring(index - 1) .. "_"
    local position = passage.position or {}
    set_fact(quests, prefix .. "line", passage.line or 0)
    set_fact(quests, prefix .. "after_stop_id", passage.afterStopId or 0)
    set_fact(quests, prefix .. "after_sequence", passage.afterSequence or 0)
    set_fact(quests, prefix .. "x", math.floor((position.x or 0) * 1000))
    set_fact(quests, prefix .. "y", math.floor((position.y or 0) * 1000))
    set_fact(quests, prefix .. "z", math.floor((position.z or 0) * 1000))
    local radians = math.rad(passage.yaw or 0)
    set_fact(quests, prefix .. "forward_x", math.floor(-math.sin(radians) * 1000000))
    set_fact(quests, prefix .. "forward_y", math.floor(math.cos(radians) * 1000000))
    -- Old passages authored before yaw support lack this flag and use the
    -- safe compatibility handoff until they are re-recorded.
    set_fact(quests, prefix .. "forward_valid", passage.yaw ~= nil and 1 or 0)
  end
  set_fact(quests, "nctc_external_network_passage_count", passage_count)
  set_fact(quests, "nctc_external_network_stop_count", count)
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
  local function publish_vector(kind, point)
    local prefix = "nctc_external_capture_id" .. tostring(capture.stopId or 0) .. "_" .. kind .. "_"
    if type(point) ~= "table" or not vector_has_position(point) then
      set_fact(quests, prefix .. "valid", 0)
      return
    end
    set_fact(quests, prefix .. "x", math.floor((point.x or 0) * 1000))
    set_fact(quests, prefix .. "y", math.floor((point.y or 0) * 1000))
    set_fact(quests, prefix .. "z", math.floor((point.z or 0) * 1000))
    set_fact(quests, prefix .. "yaw", math.floor((point.yaw or 0) * 1000))
    if kind == "berth" then
      -- The capture yaw is the surveyed direction of circulation. Publish a
      -- world-space forward vector so redscript never has to guess yaw-axis
      -- conventions when it computes the AI-only target beyond the berth.
      local radians = math.rad(point.yaw or 0)
      set_fact(quests, prefix .. "forward_x", math.floor(-math.sin(radians) * 1000000))
      set_fact(quests, prefix .. "forward_y", math.floor(math.cos(radians) * 1000000))
      set_fact(quests, prefix .. "forward_valid", 1)
    end
    set_fact(quests, prefix .. "valid", 1)
  end
  publish_vector("spawn", capture.spawn)
  publish_vector("approach", capture.approach)
  publish_vector("berth", capture.berth)
end

local function synchronize_external_survey(quests)
  local network = load_network()
  local revision = network.revision or 1
  -- Quest facts are part of a save and can be older than the external JSON.
  -- Republish on launch/load or when the external authoring data changed.
  -- Do not use the session token as a perpetual trigger: some game versions
  -- do not retain that fact reliably and would rebuild the entire network
  -- every second while a service is in motion.
  local quest_revision = fact(quests, "nctc_external_network_revision")
  local string_quest_revision = fact_as_string(quests, "nctc_external_network_revision")
  local direct_revision = game_fact("nctc_external_network_revision")
  local needs_sync = quest_revision ~= revision
    or last_published_network_revision ~= revision
  if not needs_sync then return end
  log("sync probe: jsonRevision=" .. tostring(revision)
    .. " questRevision=" .. tostring(quest_revision)
    .. " stringQuestRevision=" .. tostring(string_quest_revision)
    .. " directRevision=" .. tostring(direct_revision)
    .. " memoryRevision=" .. tostring(last_published_network_revision))

  -- Transaction boundary: redscript must not consume capture facts while CET
  -- is replacing them. Ready is restored only after every coordinate, valid
  -- flag and revision marker belongs to the same network snapshot.
  set_fact(quests, "nctc_external_network_ready", 0)
  publish_network(quests, network)
  for _, stop in ipairs(network.stops or {}) do
    local prefix = "nctc_external_capture_id" .. tostring(stop.id or 0) .. "_"
    set_fact(quests, prefix .. "spawn_valid", 0)
    set_fact(quests, prefix .. "approach_valid", 0)
    set_fact(quests, prefix .. "berth_valid", 0)
  end
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
  set_fact(quests, "nctc_external_network_revision", revision)
  set_fact(quests, "nctc_external_network_session", runtime_session_id)
  set_fact(quests, "nctc_external_network_ready", 1)
  last_published_network_revision = revision
  log("published external network transaction revision " .. tostring(revision)
    .. " readbackDirect=" .. tostring(game_fact("nctc_external_network_revision"))
    .. " readbackCName=" .. tostring(fact(quests, "nctc_external_network_revision")))
end

-- Dev-only dispatch telemetry, written by NCTCTransitSystem just before it
-- asks the engine to create the bus. It is intentionally file-log only.
local function log_dispatch_attempt(quests)
  local id = fact(quests, "nctc_dev_dispatch_id")
  -- Quest facts are restored by a save load, while this Lua runtime remains
  -- alive. Re-arm the deduplicator when that restored counter moves back.
  if id < last_dispatch_log_id then last_dispatch_log_id = id - 1 end
  if id <= last_dispatch_log_id then return end
  last_dispatch_log_id = id
  local line = fact(quests, "nctc_dev_dispatch_line")
  local stop_id = fact(quests, "nctc_dev_dispatch_stop_id")
  if fact(quests, "nctc_dev_dispatch_has_profile") ~= 1 then
    log("dispatch " .. tostring(id) .. ": L" .. tostring(line) .. " stopId " .. tostring(stop_id) .. " rejected: no spawn/berth profile")
    return
  end
  local metres = fact(quests, "nctc_dev_dispatch_spawn_distance_mm") / 1000.0
  local note = metres > 150.0 and " WARNING: beyond reliable streaming range" or ""
  log("dispatch " .. tostring(id) .. ": L" .. tostring(line) .. " stopId " .. tostring(stop_id)
    .. " spawn is " .. string.format("%.1f", metres) .. "m from V" .. note)
end

local function log_service_loop(quests)
  local id = fact(quests, "nctc_dev_loop_id")
  -- Same rule for route telemetry: otherwise every event after a load can be
  -- silently discarded as an already-seen event from the prior save state.
  if id < last_loop_log_id then last_loop_log_id = id - 1 end
  if id <= last_loop_log_id then return end
  last_loop_log_id = id
  local code = fact(quests, "nctc_dev_loop_code")
  local line = fact(quests, "nctc_dev_loop_line")
  local stop_id = fact(quests, "nctc_dev_loop_stop_id")
  local service_stop_id = fact(quests, "nctc_dev_loop_service_stop_id")
  local next_stop_id = fact(quests, "nctc_dev_loop_next_stop_id")
  local target_x = fact(quests, "nctc_dev_loop_target_x_mm") / 1000.0
  local target_y = fact(quests, "nctc_dev_loop_target_y_mm") / 1000.0
  local target_z = fact(quests, "nctc_dev_loop_target_z_mm") / 1000.0
  local ai_target_x = fact(quests, "nctc_dev_loop_ai_target_x_mm") / 1000.0
  local ai_target_y = fact(quests, "nctc_dev_loop_ai_target_y_mm") / 1000.0
  local ai_target_z = fact(quests, "nctc_dev_loop_ai_target_z_mm") / 1000.0
  local bus_x = fact(quests, "nctc_dev_loop_bus_x_mm") / 1000.0
  local bus_y = fact(quests, "nctc_dev_loop_bus_y_mm") / 1000.0
  local bus_z = fact(quests, "nctc_dev_loop_bus_z_mm") / 1000.0
  local target_distance = fact(quests, "nctc_dev_loop_target_distance_mm") / 1000.0
  local berth_longitudinal = fact(quests, "nctc_dev_loop_berth_longitudinal_mm") / 1000.0
  local berth_lateral = fact(quests, "nctc_dev_loop_berth_lateral_mm") / 1000.0
  local berth_speed = fact(quests, "nctc_dev_loop_berth_speed_mm") / 1000.0
  local dwell_polls = fact(quests, "nctc_dev_loop_dwell_polls")
  local player_aboard = fact(quests, "nctc_dev_loop_player_aboard")
  local mount_request = fact(quests, "nctc_dev_loop_mount_request")
  local states = {
    [1] = "arrived and opened doors",
    [2] = "waiting: V is not mounted in this bus",
    [3] = "V detected aboard; dwell timer started",
    [4] = "blocked: current stop was not found in the line order",
    [5] = "blocked: next stop has no complete spawn/berth profile",
    [6] = "departing for next stop",
    [7] = "one-leg destination reached",
    [10] = "dwell complete; door closure requested",
    [11] = "second AI command scheduled",
    [20] = "minimal loop: drive command sent",
    [21] = "minimal loop: berth reached",
    [22] = "minimal loop: next berth command sent",
    [23] = "minimal loop: next berth command rejected",
    [24] = "minimal loop: stopped-near fallback reached",
    [25] = "minimal loop: active AI command failed",
    [29] = "route loop: initial berth command sent",
    [30] = "route loop: berth envelope reached; service stop opened",
    [31] = "route loop: berth envelope reached; passed through to next stop",
    [32] = "route loop: departed for next stopSequence",
    [33] = "route loop: next drive command rejected",
    [34] = "route loop: next stopSequence/profile unavailable",
    [35] = "route loop: active drive command failed before arrival",
    [36] = "route loop: native command telemetry",
    [37] = "route loop: bus manually despawned",
    [38] = "route loop: native stop detected; forward berth correction sent",
    [41] = "route loop: r372n outgoing corridor armed",
    [42] = "route loop: r372n rolling post-passage handoff"
  }
  local command_extra = ""
  if code == 29 or code == 31 or code == 32 or code == 41 then
    local speed_profiles = { [0] = "fallback/manual", [1] = "dense-city", [2] = "city", [3] = "outer-city", [4] = "badlands" }
    local profile_code = fact(quests, "nctc_dev_command_speed_profile")
    command_extra = " minDistance=" .. string.format("%.2fm", fact(quests, "nctc_dev_command_minimum_distance_mm") / 1000.0)
      .. " speedLimit=" .. string.format("%.1f", fact(quests, "nctc_dev_command_speed_limit_x10") / 10.0)
      .. " profile=" .. (speed_profiles[profile_code] or ("unknown(" .. tostring(profile_code) .. ")"))
      .. string.format(" aiTarget=(%.3f, %.3f, %.3f)", ai_target_x, ai_target_y, ai_target_z)
  end
  if code == 30 or code == 32 then
    command_extra = command_extra
      .. " dwell=" .. tostring(dwell_polls)
      .. " aboard=" .. tostring(player_aboard)
      .. " mountRequest=" .. tostring(mount_request)
  end
  if code == 36 then
    local command_states = { [0] = "missing", [1] = "active", [2] = "success", [3] = "failed/cancelled" }
    command_extra = " commandState=" .. (command_states[fact(quests, "nctc_dev_command_state")] or "unknown")
      .. " previousCommandState=" .. (command_states[fact(quests, "nctc_dev_previous_command_state")] or "unknown")
      .. " speed=" .. string.format("%.2f", fact(quests, "nctc_dev_command_speed_mm") / 1000.0)
  end
  if code == 38 then
    command_extra = string.format(" correctionTarget=(%.3f, %.3f, %.3f)",
      fact(quests, "nctc_dev_correction_target_x_mm") / 1000.0,
      fact(quests, "nctc_dev_correction_target_y_mm") / 1000.0,
      fact(quests, "nctc_dev_correction_target_z_mm") / 1000.0)
  end
  if code == 42 then
    command_extra = " progress=" .. string.format("%.1fm", fact(quests, "nctc_dev_passage_progress_mm") / 1000.0)
      .. " lateral=" .. string.format("%.1fm", fact(quests, "nctc_dev_passage_lateral_mm") / 1000.0)
      .. " entrySpeed=" .. string.format("%.2f", fact(quests, "nctc_dev_passage_handoff_speed_mm") / 1000.0)
      .. " forcedStartSpeed=" .. string.format("%.2f", fact(quests, "nctc_dev_command_forced_start_speed_mm") / 1000.0)
      .. " generation=" .. tostring(fact(quests, "nctc_dev_drive_generation"))
      .. string.format(" aiTarget=(%.3f, %.3f, %.3f)", ai_target_x, ai_target_y, ai_target_z)
  end
  local session = fact(quests, "nctc_dev_service_session")
  log("service #" .. tostring(session) .. " loop " .. tostring(id) .. ": L" .. tostring(line) .. " currentStopId=" .. tostring(stop_id)
    .. " serviceStopId=" .. tostring(service_stop_id)
    .. " -> " .. tostring(next_stop_id) .. " " .. (states[code] or ("state " .. tostring(code)))
    .. string.format(" | bus=(%.3f, %.3f, %.3f) target=(%.3f, %.3f, %.3f) distance=%.1fm berth(long=%.2fm lat=%.2fm speed=%.2f)",
      bus_x, bus_y, bus_z, target_x, target_y, target_z, target_distance, berth_longitudinal, berth_lateral, berth_speed) .. command_extra)
end

local function log_native_command_event(quests)
  local id = fact(quests, "nctc_dev_native_command_event_id")
  if id < last_native_command_event_id then last_native_command_event_id = id - 1 end
  if id <= last_native_command_event_id then return end
  last_native_command_event_id = id
  local events = { [1] = "native command started", [2] = "native command ended", [3] = "native command stopped/cancelled" }
  local states = { [1] = "active/other", [2] = "success", [3] = "failure/cancelled" }
  log("native drive event #" .. tostring(id) .. ": "
    .. (events[fact(quests, "nctc_dev_native_command_event_code")] or "unknown")
    .. " object=" .. tostring(fact(quests, "nctc_dev_native_command_has_object"))
    .. " state=" .. (states[fact(quests, "nctc_dev_native_command_state")] or "missing")
    .. string.format(" | bus=(%.3f, %.3f, %.3f) speed=%.2f",
      fact(quests, "nctc_dev_native_command_x_mm") / 1000.0,
      fact(quests, "nctc_dev_native_command_y_mm") / 1000.0,
      fact(quests, "nctc_dev_native_command_z_mm") / 1000.0,
      fact(quests, "nctc_dev_native_command_speed_mm") / 1000.0))
end

local function log_service_protection(quests)
  local id = fact(quests, "nctc_dev_service_crime_suppressed_id")
  if id < last_service_crime_suppressed_id then last_service_crime_suppressed_id = id - 1 end
  if id <= last_service_crime_suppressed_id then return end
  last_service_crime_suppressed_id = id
  log("service protection #" .. tostring(id) .. ": ignored bus impact crime attribution; V heat unchanged")
end

local function log_service_calm_reaction(quests)
  local id = fact(quests, "nctc_dev_service_calm_reaction_id")
  if id < last_service_calm_reaction_id then last_service_calm_reaction_id = id - 1 end
  if id <= last_service_calm_reaction_id then return end
  last_service_calm_reaction_id = id
  log("service calm #" .. tostring(id) .. ": reaction downgraded; NCTC panic/flee suppressed")
end

local function log_stale_drive_callback(quests)
  local id = fact(quests, "nctc_dev_stale_drive_callback_id")
  if id < last_stale_drive_callback_id then last_stale_drive_callback_id = id - 1 end
  if id <= last_stale_drive_callback_id then return end
  last_stale_drive_callback_id = id
  log("stale deferred drive callback rejected | staleGeneration="
    .. tostring(fact(quests, "nctc_dev_stale_drive_generation"))
    .. " currentGeneration=" .. tostring(fact(quests, "nctc_dev_drive_generation")))
end

local function log_build_revision(quests)
  local revision = fact(quests, "nctc_dev_build_revision")
  if revision <= 0 or revision == last_build_revision then return end
  last_build_revision = revision
  if revision == 37214 then
    log("NCTC runtime build=37214 r372n generation-safe rolling handoff")
  else
    log("NCTC runtime build=" .. tostring(revision))
  end
end

registerForEvent("onUpdate", function()
  local quests = Game.GetQuestsSystem()
  if not quests then return end
  if not runtime_announced then
    runtime_announced = true
    print("[NCTC Survey] Runtime active; external path: " .. tostring(NETWORK_FILE))
  end
  log_build_revision(quests)
  log_stale_drive_callback(quests)
  log_dispatch_attempt(quests)
  log_service_loop(quests)
  log_native_command_event(quests)
  log_service_protection(quests)
  log_service_calm_reaction(quests)
  log_sequence_probe(quests)
  log_profile_probe(quests)
  local event_id = fact(quests, "nctc_survey_event_id")
  -- A save load restores the old event counter. Treat that first observed
  -- value as a baseline, never as a brand-new capture that could overwrite
  -- the external network with stale save data.
  if not survey_events_initialized then
    survey_events_initialized = true
    last_event_id = event_id
  elseif event_id < last_event_id then
    -- Loading a save restores older quest facts, including this counter and
    -- the old survey vectors. It is not a new capture. Treat it as a new
    -- baseline or it would overwrite the external JSON just saved moments
    -- earlier with stale coordinates from the save.
    last_event_id = event_id
    log("ignored restored survey event counter " .. tostring(event_id))
  elseif event_id > last_event_id then
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
  runtime_session_id = os.time()
  load_settings()
  NETWORK_FILE = OUTPUT_DIRECTORY .. "/nctc_network.json"
  DEFAULT_NETWORK_FILE = OUTPUT_DIRECTORY .. "/nctc_network.default.json"
  BACKUP_FILE = OUTPUT_DIRECTORY .. "/nctc_network.previous.json"
  LOG_FILE = OUTPUT_DIRECTORY .. "/nctc_survey.log"
  print("[NCTC Survey] Initialized; external path: " .. tostring(NETWORK_FILE))
  log("NCTC survey persistence loaded")
end)

-- CET bindings must be registered at Lua root level: neither inside onInit
-- nor from onUpdate. CET discovers these declarations as it loads the mod.
registerInput("nctc_survey_spawn", "NCTC Survey: record spawn", function(down)
  if down then capture_directly("spawn") end
end)
registerInput("nctc_survey_approach", "NCTC Survey: record approach", function(down)
  if down then capture_directly("approach") end
end)
registerInput("nctc_survey_berth", "NCTC Survey: record berth", function(down)
  if down then capture_directly("berth") end
end)
