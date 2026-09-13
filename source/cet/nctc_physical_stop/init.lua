-- NCTC first physical stop prototype.
--
-- This experiment intentionally lives in CET/Lua instead of REDscript so it
-- cannot break the game's REDscript compilation. It reads the already-published
-- external NCTC network facts, finds stop id 22 and spawns one vanilla fast-
-- travel terminal there as a visible placeholder.

local TARGET_STOP_ID = 22
local TEMPLATE_PATH = "base\\gameplay\\devices\\fast_travel\\data_term_1.ent"
local TAG = "NCTC_PhysicalStopPrototype"

local state = {
  spawned = false,
  entityID = nil,
  elapsed = 0.0,
  attempts = 0,
  lastError = nil
}

local function log(message)
  print("[NCTC Physical Stop] " .. tostring(message))
end

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

local function find_stop_position()
  local quests = Game.GetQuestsSystem()
  if not quests or fact(quests, "nctc_external_network_ready") ~= 1 then
    return nil
  end

  local count = fact(quests, "nctc_external_network_stop_count")
  for index = 0, count - 1 do
    local prefix = "nctc_external_stop_" .. tostring(index) .. "_"
    if fact(quests, prefix .. "id") == TARGET_STOP_ID then
      local x = fact(quests, prefix .. "x") / 1000.0
      local y = fact(quests, prefix .. "y") / 1000.0
      local z = fact(quests, prefix .. "z") / 1000.0
      if math.abs(x) > 1.0 or math.abs(y) > 1.0 then
        return Vector4.new(x, y, z, 1.0)
      end
      return nil
    end
  end

  return nil
end

local function make_orientation()
  -- Temporary visual orientation for stop 22. Final stop orientation will be
  -- data-driven from survey/capture geometry once the physical-spawn pipeline
  -- itself has been validated.
  local facing = Vector4.new(5.830, 1.548, 0.0, 0.0)
  return EulerAngles.ToQuat(Vector4.ToRotation(facing))
end

local function try_spawn()
  if state.spawned then return true end

  local player = Game.GetPlayer()
  if not player then return false end

  local position = find_stop_position()
  if not position then return false end

  local ok, result = pcall(function()
    local entitySystem = Game.GetDynamicEntitySystem()
    if not entitySystem then error("DynamicEntitySystem unavailable") end

    local ready = true
    pcall(function() ready = entitySystem:IsReady() end)
    if ready == false then error("DynamicEntitySystem not ready") end

    local spec = DynamicEntitySpec.new()
    spec.templatePath = TEMPLATE_PATH
    spec.position = position
    spec.orientation = make_orientation()
    spec.persistState = false
    spec.persistSpawn = false
    spec.alwaysSpawned = false
    spec.spawnInView = true
    spec.active = true
    spec.tags = { TAG }

    return entitySystem:CreateEntity(spec)
  end)

  state.attempts = state.attempts + 1
  if not ok then
    local err = tostring(result)
    if err ~= state.lastError then
      state.lastError = err
      log("spawn attempt failed: " .. err)
    end
    return false
  end

  if not result then
    return false
  end

  state.entityID = result
  state.spawned = true
  state.lastError = nil
  log(string.format("prototype stop %d spawned at %.3f, %.3f, %.3f", TARGET_STOP_ID, position.x, position.y, position.z))
  return true
end

local function cleanup()
  if not state.entityID then return end
  pcall(function()
    local entitySystem = Game.GetDynamicEntitySystem()
    if entitySystem then entitySystem:DeleteEntity(state.entityID) end
  end)
  state.entityID = nil
  state.spawned = false
end

registerForEvent("onInit", function()
  state.spawned = false
  state.entityID = nil
  state.elapsed = 0.0
  state.attempts = 0
  state.lastError = nil
  log("prototype loaded; waiting for external NCTC network")
end)

registerForEvent("onUpdate", function(dt)
  if state.spawned then return end
  state.elapsed = state.elapsed + (dt or 0.0)
  if state.elapsed < 0.5 then return end
  state.elapsed = 0.0

  -- Keep retrying during startup/load ordering. After two minutes, stop
  -- spamming attempts but leave a clear log entry.
  if state.attempts >= 240 then
    if state.attempts == 240 then
      log("prototype gave up after 240 attempts")
      state.attempts = 241
    end
    return
  end

  try_spawn()
end)

registerForEvent("onShutdown", function()
  cleanup()
end)
