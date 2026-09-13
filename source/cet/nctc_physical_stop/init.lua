-- NCTC physical stop prototype, streaming-safe revision.
--
-- The previous revision registered the stop entity while the player could be
-- kilometres away.  That only proved that an EntityID could be allocated; it
-- did not prove that the prop had actually streamed into the world.  This
-- revision waits until V is close to stop 22 before creating the entity and
-- also exposes a CET hotkey that spawns the same prop three metres in front of
-- V.  The hotkey isolates entity spawning from all NCTC network logic.

local TARGET_STOP_ID = 22
local TEMPLATE_PATH = "base\\gameplay\\devices\\fast_travel\\data_term_1.ent"
local SPAWN_RADIUS = 120.0

local state = {
  stopEntityID = nil,
  stopSpawnRequested = false,
  stopSpawnConfirmed = false,
  testEntityID = nil,
  elapsed = 0.0,
  pendingElapsed = 0.0,
  lastError = nil,
  lastDistanceBucket = nil
}

local function log(message)
  print("[NCTC Physical Stop] " .. tostring(message))
end

local function fact(quests, name)
  if not quests then return 0 end

  local ok, value = pcall(function() return quests:GetFactStr(name) end)
  if ok then
    value = tonumber(value)
    if value ~= nil then return math.floor(value) end
  end

  ok, value = pcall(function() return quests:GetFact(CName.new(name)) end)
  if ok then
    value = tonumber(value)
    if value ~= nil then return math.floor(value) end
  end

  ok, value = pcall(function() return quests:GetFact(name) end)
  if ok then
    value = tonumber(value)
    if value ~= nil then return math.floor(value) end
  end

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

local function distance(a, b)
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  local dz = (a.z or 0) - (b.z or 0)
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- exEntitySpawner is deliberately the primary method here: it is intended for
-- spawning .ent resources from CET and keeps this experiment independent from
-- REDscript.  DynamicEntitySystem remains a fallback for installations where
-- the global spawner is unavailable.
local function spawn_entity_at(position)
  local player = Game.GetPlayer()
  if not player then return nil, "player unavailable" end

  if exEntitySpawner and exEntitySpawner.Spawn then
    local ok, result = pcall(function()
      local transform = player:GetWorldTransform()
      transform:SetPosition(position)
      return exEntitySpawner.Spawn(TEMPLATE_PATH, transform, "")
    end)
    if ok and result then
      return result, "exEntitySpawner"
    end
    if not ok then
      log("exEntitySpawner failed: " .. tostring(result))
    end
  end

  local ok, result = pcall(function()
    local entitySystem = Game.GetDynamicEntitySystem()
    if not entitySystem then error("DynamicEntitySystem unavailable") end

    local spec = DynamicEntitySpec.new()
    spec.templatePath = TEMPLATE_PATH
    spec.position = position
    spec.orientation = player:GetWorldOrientation()
    spec.persistState = false
    spec.persistSpawn = false
    spec.alwaysSpawned = false
    spec.spawnInView = true
    spec.active = true
    spec.tags = { "NCTC_PhysicalStopPrototype" }
    return entitySystem:CreateEntity(spec)
  end)

  if ok and result then
    return result, "DynamicEntitySystem"
  end
  return nil, tostring(result)
end

local function delete_entity(id)
  if not id then return end

  pcall(function()
    if exEntitySpawner and exEntitySpawner.Despawn then
      local entity = Game.FindEntityByID(id)
      if entity then
        exEntitySpawner.Despawn(entity)
        return
      end
    end

    local system = Game.GetDynamicEntitySystem()
    if system then system:DeleteEntity(id) end
  end)
end

local function spawn_test_in_front()
  local player = Game.GetPlayer()
  if not player then
    log("diagnostic spawn rejected: player unavailable")
    return
  end

  if state.testEntityID then
    delete_entity(state.testEntityID)
    state.testEntityID = nil
  end

  local pos = player:GetWorldPosition()
  local forward = player:GetWorldForward()
  local target = Vector4.new(
    pos.x + forward.x * 3.0,
    pos.y + forward.y * 3.0,
    pos.z + 0.05,
    1.0
  )

  local id, method = spawn_entity_at(target)
  if id then
    state.testEntityID = id
    log(string.format("DIAGNOSTIC requested via %s at %.3f, %.3f, %.3f", method, target.x, target.y, target.z))
  else
    log("DIAGNOSTIC failed: " .. tostring(method))
  end
end

local function try_spawn_stop_when_near()
  if state.stopSpawnRequested or state.stopSpawnConfirmed then return end

  local player = Game.GetPlayer()
  if not player then return end

  local stopPosition = find_stop_position()
  if not stopPosition then return end

  local playerPosition = player:GetWorldPosition()
  local metres = distance(playerPosition, stopPosition)
  local bucket = math.floor(metres / 50.0)
  if bucket ~= state.lastDistanceBucket then
    state.lastDistanceBucket = bucket
    log(string.format("stop %d is %.1fm from V", TARGET_STOP_ID, metres))
  end

  if metres > SPAWN_RADIUS then return end

  -- A tiny Z lift prevents a prop origin exactly on the road/trottoir plane
  -- from being hidden by the surface while we validate the pipeline.
  local target = Vector4.new(stopPosition.x, stopPosition.y, stopPosition.z + 0.05, 1.0)
  local id, method = spawn_entity_at(target)
  if not id then
    local err = tostring(method)
    if err ~= state.lastError then
      state.lastError = err
      log("stop spawn failed: " .. err)
    end
    return
  end

  state.stopEntityID = id
  state.stopSpawnRequested = true
  state.pendingElapsed = 0.0
  state.lastError = nil
  log(string.format("stop %d spawn requested via %s at %.3f, %.3f, %.3f", TARGET_STOP_ID, method, target.x, target.y, target.z))
end

local function poll_stop_spawn(dt)
  if not state.stopSpawnRequested or state.stopSpawnConfirmed or not state.stopEntityID then return end

  state.pendingElapsed = state.pendingElapsed + (dt or 0.0)
  local ok, entity = pcall(function() return Game.FindEntityByID(state.stopEntityID) end)
  if ok and entity then
    state.stopSpawnConfirmed = true
    log("stop entity is physically present in the streamed world")
    return
  end

  if state.pendingElapsed >= 10.0 then
    log("stop entity did not materialize after 10s; clearing request so it can retry")
    delete_entity(state.stopEntityID)
    state.stopEntityID = nil
    state.stopSpawnRequested = false
    state.pendingElapsed = 0.0
  end
end

registerHotkey(
  "nctc_physical_stop_diagnostic",
  "NCTC: spawn physical-stop test in front of V",
  function()
    spawn_test_in_front()
  end
)

registerForEvent("onInit", function()
  state.stopEntityID = nil
  state.stopSpawnRequested = false
  state.stopSpawnConfirmed = false
  state.testEntityID = nil
  state.elapsed = 0.0
  state.pendingElapsed = 0.0
  state.lastError = nil
  state.lastDistanceBucket = nil
  log("streaming-safe prototype loaded; stop 22 will spawn only within 120m")
  log("diagnostic hotkey available: NCTC: spawn physical-stop test in front of V")
end)

registerForEvent("onUpdate", function(dt)
  poll_stop_spawn(dt)

  if state.stopSpawnConfirmed then return end
  state.elapsed = state.elapsed + (dt or 0.0)
  if state.elapsed < 0.5 then return end
  state.elapsed = 0.0
  try_spawn_stop_when_near()
end)

registerForEvent("onShutdown", function()
  delete_entity(state.stopEntityID)
  delete_entity(state.testEntityID)
  state.stopEntityID = nil
  state.testEntityID = nil
end)
