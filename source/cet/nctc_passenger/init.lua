-- Passenger cabin interaction adapted from Drive a Bus 1.2.0 by tidusMD,
-- used with the author's explicit permission. See THIRD_PARTY_NOTICES.md.
local NCTC = { tag = "NCTC.ServiceBus", ui = nil, hub = nil, visible = false,
  selected = 0, locked = false, offered = {}, lastSlot = nil,
  uiMissingLogged = false, wasInside = false }

local seats = {
  { id = "seat_back_left", sideLocKey = "LocKey#40664" },
  { id = "seat_back_right", sideLocKey = "LocKey#40665" }
}

local function bus()
  local dynamic = Game.GetDynamicEntitySystem()
  if not dynamic then return nil end
  local ids = dynamic:GetTaggedIDs(NCTC.tag)
  return ids and #ids > 0 and Game.FindEntityByID(ids[1]) or nil
end

local function localPosition(vehicle, player)
  local origin, forward, right, up = vehicle:GetWorldPosition(), vehicle:GetWorldForward(), vehicle:GetWorldRight(), vehicle:GetWorldUp()
  local world = player:GetWorldPosition()
  local fp, rp, upoint = Vector4.new(origin.x+forward.x, origin.y+forward.y, origin.z+forward.z, origin.w), Vector4.new(origin.x+right.x, origin.y+right.y, origin.z+right.z, origin.w), Vector4.new(origin.x+up.x, origin.y+up.y, origin.z+up.z, origin.w)
  local yz, xz, xy = Vector4.ProjectPointToPlane(origin, fp, upoint, world), Vector4.ProjectPointToPlane(origin, rp, upoint, world), Vector4.ProjectPointToPlane(origin, fp, rp, world)
  local vx, vy, vz = Vector4.new(world.x-yz.x, world.y-yz.y, world.z-yz.z, 1), Vector4.new(world.x-xz.x, world.y-xz.y, world.z-xz.z, 1), Vector4.new(world.x-xy.x, world.y-xy.y, world.z-xy.z, 1)
  local x, y, z = Vector4.Length(vx), Vector4.Length(vy), Vector4.Length(vz)
  if Vector4.Dot(vx, right) < 0 then x = -x end
  if Vector4.Dot(vy, forward) < 0 then y = -y end
  if Vector4.Dot(vz, up) < 0 then z = -z end
  return Vector4.new(x, y, z, 1)
end

local function inside(vehicle, player)
  local p = localPosition(vehicle, player)
  return p.x > -1.20 and p.x < 1.20 and p.y > -3.00 and p.y < 5.00 and p.z > 0.00 and p.z < 1.80
end

local function free(vehicle, id)
  local ps = vehicle:GetVehiclePS()
  return ps and not ps:IsSlotOccupiedByNPC(CName.new(id))
end

local function setDoor(vehicle, open)
  local ps = vehicle and vehicle:GetVehiclePS() or nil
  if not ps then return end
  local state = ps:GetDoorState(EVehicleDoor.seat_front_right)
  if open and state ~= VehicleDoorState.Open then
    local evt = VehicleDoorOpen.new(); evt.slotID = CName.new("seat_front_right"); evt.forceScene = false
    ps:QueuePSEvent(ps, evt)
  elseif not open and state ~= VehicleDoorState.Closed then
    local evt = VehicleDoorClose.new(); evt.slotID = CName.new("seat_front_right"); evt.forceScene = false
    ps:QueuePSEvent(ps, evt)
  end
end

local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i].id ~= b[i].id then return false end end
  return true
end

local function available(vehicle, player)
  -- Exact rear-seat interaction area from Drive a Bus 1.2.0.  The player may
  -- walk anywhere in the cabin, but the prompt is only presented from the
  -- aisle immediately in front of the two validated rear workspots.
  local p = localPosition(vehicle, player)
  if not (p.x > -0.50 and p.x < 0.50 and p.y > -1.20 and p.y < -0.20 and p.z > 0.00 and p.z < 1.80) then return {} end
  local angle = player:GetWorldOrientation():ToEulerAngles().yaw - vehicle:GetWorldOrientation():ToEulerAngles().yaw
  if angle > 180 then angle = angle - 360 elseif angle < -180 then angle = angle + 360 end
  local result = {}
  if math.abs(angle) < 40 or math.abs(angle) > 140 then
    for _, seat in ipairs(seats) do if free(vehicle, seat.id) then table.insert(result, seat) end end
  elseif angle > 0 and free(vehicle, seats[1].id) then
    table.insert(result, seats[1])
  elseif angle < 0 and free(vehicle, seats[2].id) then
    table.insert(result, seats[2])
  end
  return result
end

local function makeHub()
  local hub = gameinteractionsvisListChoiceHubData.new()
  -- Drive a Bus deliberately uses a fresh hub id. A fixed id can collide with
  -- another native interaction and results in choices being built but never
  -- rendered, which is exactly what the NCTC diagnostic log showed.
  -- The hub is an implementation detail required by the interaction UI.  It
  -- deliberately has no visible title: only the localized Sit rows matter.
  hub.title, hub.activityState, hub.hubPriority, hub.id = "", gameinteractionsvisEVisualizerActivityState.Active, 1, 77777 + math.random(99999)
  hub.choices = {}
  for _, seat in ipairs(NCTC.offered) do
    local caption, kind = gameinteractionsChoiceCaption.new(), gameinteractionsChoiceTypeWrapper.new()
    caption:AddPartFromRecord(TweakDBInterface.GetChoiceCaptionIconPartRecord("ChoiceCaptionParts.SitIcon")); kind:SetType(gameinteractionsChoiceType.Selected)
    local choice = gameinteractionsvisListChoiceData.new()
    choice.localizedName = GetLocalizedText("LocKey#522") .. " [" .. GetLocalizedText(seat.sideLocKey) .. "]"
    choice.inputActionName, choice.captionParts, choice.type = CName.new("None"), caption, kind
    table.insert(hub.choices, choice)
  end
  return hub
end

local function hide()
  if not NCTC.visible then return end
  NCTC.visible, NCTC.hub = false, nil
  if NCTC.ui then
    local defs = GetAllBlackboardDefs().UIInteractions
    NCTC.ui:OnDialogsData(Game.GetBlackboardSystem():Get(defs):GetVariant(defs.DialogChoiceHubs))
  end
end

local function show()
  if not NCTC.ui or #NCTC.offered == 0 then
    if not NCTC.ui and not NCTC.uiMissingLogged then
      print("[NCTC Passenger] Seat prompt waiting for InteractionUIBase")
      NCTC.uiMissingLogged = true
    end
    -- Do not latch the prompt in a fictitious visible state.  The HUD can be
    -- initialized one or more frames after V enters the cabin; clearing this
    -- flag makes onUpdate retry until InteractionUIBase actually exists.
    NCTC.visible = false
    return
  end
  NCTC.uiMissingLogged = false
  NCTC.hub = makeHub()
  local defs = GetAllBlackboardDefs().UIInteractions
  local board = Game.GetBlackboardSystem():Get(defs)
  board:SetInt(defs.ActiveChoiceHubID, NCTC.hub.id)
  NCTC.ui:OnDialogsSelectIndex(NCTC.selected); NCTC.ui:OnDialogsData(board:GetVariant(defs.DialogChoiceHubs))
  NCTC.ui:OnInteractionsChanged(); NCTC.ui:UpdateListBlackboard(); NCTC.ui:OnDialogsActivateHub(NCTC.hub.id)
end

local function mount(seat)
  local player, vehicle = Game.GetPlayer(), bus()
  if not player or not vehicle or player:GetMountedVehicle() or not seat or not free(vehicle, seat.id) then return end
  local data, slot, info, request = MountEventData.new(), MountingSlotId.new(), MountingInfo.new(), MountingRequest.new()
  data.isInstant, data.slotName, data.mountParentEntityId = false, seat.id, vehicle:GetEntityID(); slot.id = seat.id
  info.childId, info.parentId, info.slotId = player:GetEntityID(), vehicle:GetEntityID(), slot
  request.lowLevelMountingInfo, request.mountData = info, data
  print("[NCTC Passenger] Mount requested: " .. seat.id)
  Game.GetMountingFacility():Mount(request); hide()
end

registerForEvent("onInit", function()
  Observe("InteractionUIBase", "OnInitialize", function(this) NCTC.ui = this end)
  Observe("InteractionUIBase", "OnDialogsData", function(this) NCTC.ui = this end)
  Observe("InteractionUIBase", "OnUninitialize", function(this) if NCTC.ui == this then NCTC.ui = nil end end)
  Override("InteractionUIBase", "OnDialogsData", function(_, value, wrapped)
    if NCTC.visible and NCTC.hub then local data=FromVariant(value); local hubs=data.choiceHubs; table.insert(hubs,NCTC.hub); data.choiceHubs=hubs; wrapped(ToVariant(data)) else wrapped(value) end
  end)
  Override("InteractionUIBase", "OnDialogsSelectIndex", function(_, index, wrapped) wrapped(NCTC.visible and NCTC.selected or index) end)
  Override("dialogWidgetGameController", "OnDialogsActivateHub", function(_, id, wrapped) return wrapped(NCTC.visible and NCTC.hub and NCTC.hub.id or id) end)
  Observe("PlayerPuppet", "OnAction", function(_, action, consumer)
    if NCTC.locked or action:GetType(action).value ~= "BUTTON_PRESSED" or action:GetValue(action) <= 0 or not NCTC.visible then return end
    local name=action:GetName(action).value
    if name == "ChoiceApply" then NCTC.locked=true; consumer:Consume(); mount(NCTC.offered[NCTC.selected+1])
    elseif name == "ChoiceScrollUp" or name == "ChoiceScrollDown" then NCTC.locked=true; consumer:Consume(); NCTC.selected=(NCTC.selected+(name=="ChoiceScrollUp" and 1 or -1)) % #NCTC.offered end
  end)
  print("[NCTC Passenger] Drive a Bus passenger interaction initialized")
end)

registerForEvent("onUpdate", function()
  NCTC.locked=false
  local player, vehicle = Game.GetPlayer(), bus()
  if not player or not vehicle then
    local quests = Game.GetQuestsSystem()
    if quests then quests:SetFactStr("nctc_player_in_service_bus", 0) end
    hide(); return
  end
  local quests=Game.GetQuestsSystem(); local state=quests and quests:GetFact(CName.new("nctc_dev_loop_code")) or 0
  setDoor(vehicle, state == 1 or state == 2 or state == 3)
  if player:GetMountedVehicle() then hide(); return end
  local offered=available(vehicle, player)
  local isInside = inside(vehicle, player)
  local quests = Game.GetQuestsSystem()
  if quests then quests:SetFactStr("nctc_player_in_service_bus", isInside and 1 or 0) end
  if isInside ~= NCTC.wasInside then
    NCTC.wasInside = isInside
    print(isInside and "[NCTC Passenger] Player entered walkable cabin" or "[NCTC Passenger] Player left walkable cabin")
  end
  if not same(NCTC.offered, offered) then
    hide(); NCTC.offered, NCTC.selected=offered, 0
    local names = {}
    for _, seat in ipairs(offered) do table.insert(names, seat.id) end
    print("[NCTC Passenger] Seat choices: " .. (#names > 0 and table.concat(names, ", ") or "none"))
  end
  if #offered > 0 and not NCTC.visible then NCTC.visible=true; show() elseif #offered == 0 then hide() end
end)
