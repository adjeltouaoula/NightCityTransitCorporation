-- Appended to nctc_survey/init.lua by the prototype builder.
-- This is intentionally kept inside the already validated survey CET module.

local NCTC_TEST_TEMPLATE = "base\\gameplay\\devices\\fast_travel\\data_term_1.ent"
local NCTC_TEST_STOP_ID = 22
local NCTC_TEST_STOP_MAX_DISTANCE = 150.0
local nctcTestEntity = nil
local nctcStopEntity = nil

local function nctcTestLog(text)
  print("[NCTC Test] " .. tostring(text))
end

local function nctcDeleteEntity(id)
  if not id then return end
  pcall(function()
    local system = Game.GetDynamicEntitySystem()
    if system then system:DeleteEntity(id) end
  end)
end

local function nctcCreateTerminal(position, orientation)
  local ok, id = pcall(function()
    local system = Game.GetDynamicEntitySystem()
    if not system then return nil end
    local spec = DynamicEntitySpec.new()
    spec.templatePath = NCTC_TEST_TEMPLATE
    spec.position = position
    spec.orientation = orientation
    spec.persistState = false
    spec.persistSpawn = false
    spec.alwaysSpawned = false
    spec.spawnInView = true
    spec.active = true
    return system:CreateEntity(spec)
  end)

  if ok and id then return id end
  nctcTestLog("terminal spawn failed: " .. tostring(id))
  return nil
end

local function nctcSpawnTestTerminal()
  local player = Game.GetPlayer()
  if not player then return end

  nctcDeleteEntity(nctcTestEntity)
  nctcTestEntity = nil

  local p = player:GetWorldPosition()
  local f = player:GetWorldForward()
  local target = Vector4.new(p.x + f.x * 3.0, p.y + f.y * 3.0, p.z + 0.10, 1.0)
  local id = nctcCreateTerminal(target, player:GetWorldOrientation())

  if id then
    nctcTestEntity = id
    nctcTestLog(string.format("local terminal requested at %.3f, %.3f, %.3f", target.x, target.y, target.z))
  end
end

local function nctcFindAuthoredStop(stopId)
  -- load_network() is defined by nctc_survey above this appended chunk. Using
  -- it means this test consumes the exact same authored JSON that drives the
  -- development network instead of maintaining a second reader or hard-coded
  -- coordinates here.
  local network = load_network()
  if not network or type(network.stops) ~= "table" then return nil end

  for _, stop in ipairs(network.stops) do
    if tonumber(stop.id) == tonumber(stopId) and stop.position then
      return stop
    end
  end
  return nil
end

local function nctcDistance(a, b)
  local dx = (a.x or 0.0) - (b.x or 0.0)
  local dy = (a.y or 0.0) - (b.y or 0.0)
  local dz = (a.z or 0.0) - (b.z or 0.0)
  return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function nctcSpawnAuthoredStopTerminal()
  local player = Game.GetPlayer()
  if not player then
    nctcTestLog("stop test rejected: player unavailable")
    return
  end

  local stop = nctcFindAuthoredStop(NCTC_TEST_STOP_ID)
  if not stop then
    nctcTestLog("stop 22 not found in active nctc_network.json")
    return
  end

  local stopPos = Vector4.new(stop.position.x, stop.position.y, stop.position.z + 0.10, 1.0)
  local playerPos = player:GetWorldPosition()
  local metres = nctcDistance(playerPos, stopPos)

  nctcTestLog(string.format(
    "stop %d '%s' data position = %.3f, %.3f, %.3f | V distance = %.1fm",
    NCTC_TEST_STOP_ID,
    tostring(stop.stopName or stop.name or "unnamed"),
    stopPos.x, stopPos.y, stopPos.z,
    metres
  ))

  if metres > NCTC_TEST_STOP_MAX_DISTANCE then
    nctcTestLog(string.format(
      "not spawning: move within %.0fm of stop %d so its world sector is streamed",
      NCTC_TEST_STOP_MAX_DISTANCE,
      NCTC_TEST_STOP_ID
    ))
    return
  end

  nctcDeleteEntity(nctcStopEntity)
  nctcStopEntity = nil

  local id = nctcCreateTerminal(stopPos, player:GetWorldOrientation())
  if id then
    nctcStopEntity = id
    nctcTestLog("SUCCESS: terminal requested at authored Centre ville stop position")
  end
end

registerInput("nctc_physical_stop_test", "NCTC TEST: spawn terminal 3m in front of V", function(down)
  if down then nctcSpawnTestTerminal() end
end)

registerInput("nctc_physical_stop_authored_22", "NCTC TEST: spawn terminal at Centre ville (stop 22)", function(down)
  if down then nctcSpawnAuthoredStopTerminal() end
end)

registerForEvent("onInit", function()
  nctcTestEntity = nil
  nctcStopEntity = nil
  nctcTestLog("bindings registered inside nctc_survey")
  nctcTestLog("next test: Centre ville stop 22 uses authored network coordinates")
end)

registerForEvent("onShutdown", function()
  nctcDeleteEntity(nctcTestEntity)
  nctcDeleteEntity(nctcStopEntity)
  nctcTestEntity = nil
  nctcStopEntity = nil
end)
