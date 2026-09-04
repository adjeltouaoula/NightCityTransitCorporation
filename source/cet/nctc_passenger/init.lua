-- Interior passenger-seat interaction restored verbatim from the validated
-- NCBN 0.0.13 port of Drive a Bus by tidusMD, then retargeted to NCTC.
-- (MIT, used with permission). See THIRD_PARTY_NOTICES.md.
-- NCBN uses the vanilla Mahir entity. Only its two validated rear passenger
-- workspots are offered to V; neither front seat is ever proposed.

local NCBN = { tag = "NightCityBusNetwork.PrototypeBus", interactionUI = nil, choiceHub = nil,
    choiceVisible = false, selectedSeat = 0, inputLocked = false, offeredSeats = {},
    uiMissingLogged = false, wasInside = false, lastMountedSlot = nil }

-- Local-space zone in the aisle beside the two validated rear passenger seats.
local seatAreas = {
    { id = "seat_back_left", label = "Sit — left rear seat", minX = -0.50, maxX = 0.50, minY = -1.20, maxY = -0.20, minZ = 0.00, maxZ = 1.80, facing = "rear" },
    { id = "seat_back_right", label = "Sit — right rear seat", minX = -0.50, maxX = 0.50, minY = -1.20, maxY = -0.20, minZ = 0.00, maxZ = 1.80, facing = "rear" },
}

local passengerSlots = { seat_back_left = true, seat_back_right = true }

local function getFact(name)
    local quests = Game.GetQuestsSystem()
    if not quests then return 0 end
    local ok, value = pcall(function() return quests:GetFact(CName.new(name)) end)
    return ok and value or 0
end

local function setFact(name, value)
    local quests = Game.GetQuestsSystem()
    if not quests then return false end
    return pcall(function() quests:SetFact(CName.new(name), value) end)
end

NCBN.tag = "NCTC.ServiceBus"

local function findServiceBus()
    local dynamic = Game.GetDynamicEntitySystem()
    if not dynamic then return nil end
    local ids = dynamic:GetTaggedIDs(NCBN.tag)
    return ids and #ids > 0 and Game.FindEntityByID(ids[1]) or nil
end

local function localPosition(bus, player)
    local origin, forward, right, up = bus:GetWorldPosition(), bus:GetWorldForward(), bus:GetWorldRight(), bus:GetWorldUp()
    local world = player:GetWorldPosition()
    local fp = Vector4.new(origin.x + forward.x, origin.y + forward.y, origin.z + forward.z, origin.w)
    local rp = Vector4.new(origin.x + right.x, origin.y + right.y, origin.z + right.z, origin.w)
    local upoint = Vector4.new(origin.x + up.x, origin.y + up.y, origin.z + up.z, origin.w)
    local yz, xz, xy = Vector4.ProjectPointToPlane(origin, fp, upoint, world), Vector4.ProjectPointToPlane(origin, rp, upoint, world), Vector4.ProjectPointToPlane(origin, fp, rp, world)
    local vx, vy, vz = Vector4.new(world.x-yz.x, world.y-yz.y, world.z-yz.z, 1), Vector4.new(world.x-xz.x, world.y-xz.y, world.z-xz.z, 1), Vector4.new(world.x-xy.x, world.y-xy.y, world.z-xy.z, 1)
    local x, y, z = Vector4.Length(vx), Vector4.Length(vy), Vector4.Length(vz)
    if Vector4.Dot(vx, right) < 0 then x = -x end
    if Vector4.Dot(vy, forward) < 0 then y = -y end
    if Vector4.Dot(vz, up) < 0 then z = -z end
    return Vector4.new(x, y, z, 1)
end

local function lookAngle(bus, player)
    local angle = player:GetWorldOrientation():ToEulerAngles().yaw - bus:GetWorldOrientation():ToEulerAngles().yaw
    return angle > 180 and angle - 360 or (angle < -180 and angle + 360 or angle)
end

local function playerIsInside(bus, player)
    local p = localPosition(bus, player)
    return p.x > -1.20 and p.x < 1.20 and p.y > -3.00 and p.y < 5.00 and p.z > 0.00 and p.z < 1.80
end

local function isSeatFree(bus, seat)
    local ps = bus:GetVehiclePS()
    return ps and not ps:IsSlotOccupiedByNPC(CName.new(seat))
end

local function isSameEntity(left, right)
    return left and right and left:GetEntityID().hash == right:GetEntityID().hash
end

local function setBoardingDoor(bus, open)
    local ps = bus and bus:GetVehiclePS() or nil
    if not ps then return end
    local current = ps:GetDoorState(EVehicleDoor.seat_front_right)
    if open and current ~= VehicleDoorState.Open then
        local event = VehicleDoorOpen.new()
        event.slotID, event.forceScene = CName.new("seat_front_right"), false
        ps:QueuePSEvent(ps, event)
    elseif not open and current ~= VehicleDoorState.Closed then
        local event = VehicleDoorClose.new()
        event.slotID, event.forceScene = CName.new("seat_front_right"), false
        ps:QueuePSEvent(ps, event)
    end
end

local function sameSeats(left, right)
    if #left ~= #right then return false end
    for i = 1, #left do if left[i].id ~= right[i].id then return false end end
    return true
end

local function offeredSeats(bus, player)
    if not playerIsInside(bus, player) then return {} end
    local p, angle, result = localPosition(bus, player), lookAngle(bus, player), {}
    for _, seat in ipairs(seatAreas) do
        if p.x > seat.minX and p.x < seat.maxX and p.y > seat.minY and p.y < seat.maxY and p.z > seat.minZ and p.z < seat.maxZ and isSeatFree(bus, seat.id) then
            -- The two rear seats share the same aisle zone. The vanilla Mahir
            -- mirrors their physical slot names, so aim selection is reversed.
            if seat.facing == "rear" then
                if (seat.id == "seat_back_left" and not (angle < -40 and angle > -140)) or (seat.id == "seat_back_right" and not (angle > 40 and angle < 140)) then table.insert(result, seat) end
            end
        end
    end
    return result
end

local function makeChoiceHub()
    local hub = gameinteractionsvisListChoiceHubData.new()
    hub.title, hub.activityState, hub.hubPriority, hub.id = "Night City Bus Network", gameinteractionsvisEVisualizerActivityState.Active, 1, 77901
    local choices = {}
    for _, seat in ipairs(NCBN.offeredSeats) do
        local caption, choiceType = gameinteractionsChoiceCaption.new(), gameinteractionsChoiceTypeWrapper.new()
        caption:AddPartFromRecord(TweakDBInterface.GetChoiceCaptionIconPartRecord("ChoiceCaptionParts.SitIcon"))
        choiceType:SetType(gameinteractionsChoiceType.Selected)
        local choice = gameinteractionsvisListChoiceData.new()
        choice.localizedName, choice.inputActionName, choice.captionParts, choice.type = seat.label, CName.new("None"), caption, choiceType
        table.insert(choices, choice)
    end
    hub.choices = choices
    return hub
end

local function hideChoice()
    if not NCBN.choiceVisible then return end
    NCBN.choiceVisible, NCBN.choiceHub = false, nil
    if NCBN.interactionUI then
        local defs = GetAllBlackboardDefs().UIInteractions
        NCBN.interactionUI:OnDialogsData(Game.GetBlackboardSystem():Get(defs):GetVariant(defs.DialogChoiceHubs))
    end
end

local function showChoice()
    if not NCBN.interactionUI or #NCBN.offeredSeats == 0 then
        if not NCBN.uiMissingLogged then print("[NCBN] Seat prompt waiting for InteractionUIBase."); NCBN.uiMissingLogged = true end
        NCBN.choiceVisible = false
        return
    end
    NCBN.uiMissingLogged = false
    NCBN.choiceHub = makeChoiceHub()
    local defs = GetAllBlackboardDefs().UIInteractions
    local blackboard = Game.GetBlackboardSystem():Get(defs)
    blackboard:SetInt(defs.ActiveChoiceHubID, NCBN.choiceHub.id)
    local data = blackboard:GetVariant(defs.DialogChoiceHubs)
    NCBN.interactionUI:OnDialogsSelectIndex(NCBN.selectedSeat)
    NCBN.interactionUI:OnDialogsData(data)
    NCBN.interactionUI:OnInteractionsChanged()
    NCBN.interactionUI:UpdateListBlackboard()
    NCBN.interactionUI:OnDialogsActivateHub(NCBN.choiceHub.id)
end

local function mountPassenger(seat)
    local player, bus = Game.GetPlayer(), findServiceBus()
    if not player or not bus or player:GetMountedVehicle() ~= nil or not seat or not isSeatFree(bus, seat.id) then return end
    local data, slot, info, request = MountEventData.new(), MountingSlotId.new(), MountingInfo.new(), MountingRequest.new()
    data.isInstant, data.slotName, data.mountParentEntityId = false, seat.id, bus:GetEntityID()
    slot.id = seat.id
    info.childId, info.parentId, info.slotId = player:GetEntityID(), bus:GetEntityID(), slot
    request.lowLevelMountingInfo, request.mountData = info, data
    Game.GetMountingFacility():Mount(request)
    hideChoice()
end

registerForEvent("onInit", function()
    Observe("InteractionUIBase", "OnInitialize", function(this) NCBN.interactionUI = this end)
    Observe("InteractionUIBase", "OnDialogsData", function(this) NCBN.interactionUI = this end)
    Observe("InteractionUIBase", "OnUninitialize", function(this) if NCBN.interactionUI == this then NCBN.interactionUI = nil end end)
    Override("InteractionUIBase", "OnDialogsData", function(_, value, wrapped)
        if NCBN.choiceVisible and NCBN.choiceHub then
            local data = FromVariant(value)
            -- FromVariant properties are copied. Reassigning the modified
            -- array is required or the HUD never receives our seat choice.
            local hubs = data.choiceHubs
            table.insert(hubs, NCBN.choiceHub)
            data.choiceHubs = hubs
            wrapped(ToVariant(data))
        else wrapped(value) end
    end)
    Override("InteractionUIBase", "OnDialogsSelectIndex", function(_, index, wrapped) wrapped(NCBN.choiceVisible and NCBN.selectedSeat or index) end)
    Override("dialogWidgetGameController", "OnDialogsActivateHub", function(_, id, wrapped) return wrapped(NCBN.choiceVisible and NCBN.choiceHub and NCBN.choiceHub.id or id) end)
    Observe("PlayerPuppet", "OnAction", function(_, action, consumer)
        if NCBN.inputLocked or action:GetType(action).value ~= "BUTTON_PRESSED" or action:GetValue(action) <= 0 then return end
        local name = action:GetName(action).value
        if NCBN.choiceVisible and name == "ChoiceApply" then
            NCBN.inputLocked = true; consumer:Consume(); mountPassenger(NCBN.offeredSeats[NCBN.selectedSeat + 1])
        elseif NCBN.choiceVisible and (name == "ChoiceScrollUp" or name == "ChoiceScrollDown") then
            NCBN.inputLocked = true; consumer:Consume()
            NCBN.selectedSeat = (NCBN.selectedSeat + (name == "ChoiceScrollUp" and 1 or -1)) % #NCBN.offeredSeats
        elseif name == "ChoiceApply" then
            -- The cabin is entered simply by walking through its open door.
            -- Consume the normal vehicle-enter choice when the service bus is
            -- targeted so the engine cannot mount V into its control slot.
            local player, bus = Game.GetPlayer(), findServiceBus()
            local target = player and Game.GetTargetingSystem():GetLookAtObject(player) or nil
            if player and bus and target and isSameEntity(target, bus) and not playerIsInside(bus, player) then
                NCBN.inputLocked = true; consumer:Consume()
            end
        end
    end)
    print("[NCBN] Interior passenger-seat interaction initialized.")
end)

registerForEvent("onUpdate", function()
    NCBN.inputLocked = false
    local player, bus = Game.GetPlayer(), findServiceBus()
    if not player or not bus then
        setFact("nctc_player_in_service_bus", 0)
        hideChoice()
        return
    end
    local distance = Vector4.Distance(player:GetWorldPosition(), bus:GetWorldPosition())
    local isMounted = player:GetMountedVehicle() ~= nil
    local insideNow = playerIsInside(bus, player)
    -- Keep the validated Drive a Bus proximity behaviour, narrowed to 5m and
    -- authorized only while NCTC has the stationary bus at a scheduled stop.
    local atStop = getFact("nctc_service_bus_at_stop") > 0
    setBoardingDoor(bus, atStop and math.abs(bus:GetCurrentSpeed()) <= 1.00 and not isMounted and distance < 5.00)

    if isMounted then
        setFact("nctc_player_in_service_bus", isSameEntity(player:GetMountedVehicle(), bus) and 1 or 0)
        local slot = bus:GetSlotIdForMountedObject(player)
        local slotName = slot and slot.value or "unknown"
        if slotName ~= NCBN.lastMountedSlot then
            NCBN.lastMountedSlot = slotName
            print("[NCBN] Player mounted slot: " .. slotName .. (passengerSlots[slotName] and " (passenger)" or " (forbidden)"))
        end
        hideChoice()
        return
    end
    NCBN.lastMountedSlot = nil
    local inside = insideNow
    setFact("nctc_player_in_service_bus", inside and 1 or 0)
    if inside ~= NCBN.wasInside then
        NCBN.wasInside = inside
        print(inside and "[NCBN] Player entered the walkable cabin." or "[NCBN] Player left the walkable cabin.")
    end
    local seats = offeredSeats(bus, player)
    if not sameSeats(NCBN.offeredSeats, seats) then
        hideChoice()
        NCBN.offeredSeats, NCBN.selectedSeat = seats, 0
        local names = {}
        for _, seat in ipairs(seats) do table.insert(names, seat.id) end
        print("[NCBN] Seat choices: " .. (#names > 0 and table.concat(names, ", ") or "none"))
    end
    if #seats > 0 and not NCBN.choiceVisible then
        NCBN.choiceVisible = true
        showChoice()
    elseif #seats == 0 then hideChoice() end
end)
