-- Appended to nctc_survey/init.lua by the prototype builder.

local NCTC_TEST_TEMPLATE = "base\\gameplay\\devices\\fast_travel\\data_term_1.ent"
local nctcTestEntity = nil

local function nctcTestLog(text)
  print("[NCTC Test] " .. tostring(text))
end

local function nctcSpawnTestTerminal()
  local player = Game.GetPlayer()
  if not player then return end

  if nctcTestEntity then
    pcall(function()
      local oldSystem = Game.GetDynamicEntitySystem()
      if oldSystem then oldSystem:DeleteEntity(nctcTestEntity) end
    end)
    nctcTestEntity = nil
  end

  local p = player:GetWorldPosition()
  local f = player:GetWorldForward()
  local target = Vector4.new(p.x + f.x * 3.0, p.y + f.y * 3.0, p.z + 0.10, 1.0)

  local ok, id = pcall(function()
    local system = Game.GetDynamicEntitySystem()
    if not system then return nil end
    local spec = DynamicEntitySpec.new()
    spec.templatePath = NCTC_TEST_TEMPLATE
    spec.position = target
    spec.orientation = player:GetWorldOrientation()
    spec.persistState = false
    spec.persistSpawn = false
    spec.alwaysSpawned = false
    spec.spawnInView = true
    spec.active = true
    return system:CreateEntity(spec)
  end)

  if ok and id then
    nctcTestEntity = id
    nctcTestLog("terminal spawn requested 3m in front of V")
  else
    nctcTestLog("terminal spawn failed: " .. tostring(id))
  end
end

registerInput("nctc_physical_stop_test", "NCTC TEST: spawn terminal 3m in front of V", function(down)
  if down then nctcSpawnTestTerminal() end
end)

registerForEvent("onInit", function()
  nctcTestEntity = nil
  nctcTestLog("binding registered inside nctc_survey")
end)
