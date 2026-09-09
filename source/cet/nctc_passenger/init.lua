-- Interior passenger-seat interaction restored verbatim from the validated
-- NCBN 0.0.13 port of Drive a Bus by tidusMD, then retargeted to NCTC.
-- (MIT, used with permission). See THIRD_PARTY_NOTICES.md.
-- NCBN uses the vanilla Mahir entity. Only its two validated rear passenger
-- workspots are offered to V; neither front seat is ever proposed.

local NCBN = { tag = "NightCityBusNetwork.PrototypeBus", interactionUI = nil, choiceHub = nil,
    choiceVisible = false, selectedSeat = 0, inputLocked = false, offeredSeats = {},
    uiMissingLogged = false, wasInside = false, lastMountedSlot = nil,
    passengerMountRequested = false, mountRequestDeadline = 0, wasMounted = false,
    hubChoiceVisible = false, hubChoiceHub = nil, hubChoices = {}, selectedHubLine = 0,
    hubChoiceRevision = -1, lastInsideLocal = nil }

-- Local-space zone in the aisle beside the two validated rear passenger seats.
local seatAreas = {
    { id = "seat_back_left", label = "Sit — left rear seat", minX = -0.50, maxX = 0.50, minY = -1.20, maxY = -0.20, minZ = 0.00, maxZ = 1.80, facing = "rear" },
    { id = "seat_back_right", label = "Sit — right rear seat", minX = -0.50, maxX = 0.50, minY = -1.20, maxY = -0.20, minZ = 0.00, maxZ = 1.80, facing = "rear" },
}

local passengerSlots = { seat_back_left = true, seat_back_right = true }

local function setFact(name, value)
    local quests = Game.GetQuestsSystem()
    if not quests then return false end
    -- Hub state is written by redscript through QuestsSystem.SetFact.  CET
    -- must use this same fact store: SetFactStr is a separate string store
    -- and made a stale choice list survive after V left the stop radius.
    return pcall(function() quests:SetFact(CName.new(name), value) end)
end

local function getFact(name)
    local quests = Game.GetQuestsSystem()
    if not quests then return 0 end
    local ok, value = pcall(function() return quests:GetFact(CName.new(name)) end)
    if ok and type(value) == "number" then return value end
    ok, value = pcall(function() return quests:GetFact(name) end)
    if ok and type(value) == "number" then return value end
    -- Compatibility only for legacy facts written by earlier dev-kit builds.
    ok, value = pcall(function() return quests:GetFactStr(name) end)
    value = tonumber(value)
    return ok and value ~= nil and math.floor(value) or 0
end

local function signalTransitSystem(value)
    local container = Game.GetScriptableSystemsContainer()
    if not container then return false end
    local ok, system = pcall(function() return container:Get("NCTC.NCTCTransitSystem") end)
    if not ok or not system then
        ok, system = pcall(function() return container:Get(CName.new("NCTC.NCTCTransitSystem")) end)
    end
    if not ok or not system then return false end
    return pcall(function() system:SetPlayerAboard(value) end)
end

local function requestHubService(choice)
    if not choice then return false end
    local container = Game.GetScriptableSystemsContainer()
    if not container then return false end
    local ok, system = pcall(function() return container:Get("NCTC.NCTCTransitSystem") end)
    if not ok or not system then ok, system = pcall(function() return container:Get(CName.new("NCTC.NCTCTransitSystem")) end) end
    if not ok or not system then return false end
    local pos = Vector4.new(choice.x, choice.y, choice.z, 1)
    local requestOk, accepted = pcall(function() return system:RequestService(tostring(choice.line), choice.stopId, pos) end)
    if requestOk and accepted then
        print("[NCBN] Hub choice selected: line " .. tostring(choice.line) .. ", stopId " .. tostring(choice.stopId))
        -- Redscript owns the game's violet notification style. Signal it to
        -- display the same confirmation used by a one-line stop.
        setFact("nctc_hub_choice_notify_line", choice.line)
        setFact("nctc_hub_choice_open", 0)
    end
    return requestOk and accepted
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

-- D3 read-only diagnostics. Rays test query collision, not character blocking.
local doorTrace = { elapsed = 0, id = nil, state = nil, failed = false }
local function doorRead(fn)
    local ok, value = pcall(fn)
    return ok and tostring(value) or ("unavailable:" .. tostring(value))
end
local function doorWorldPoint(bus, x, y, z)
    local o, r, f, u = bus:GetWorldPosition(), bus:GetWorldRight(), bus:GetWorldForward(), bus:GetWorldUp()
    return Vector4.new(o.x+r.x*x+f.x*y+u.x*z, o.y+r.y*x+f.y*y+u.y*z,
        o.z+r.z*x+f.z*y+u.z*z, 1)
end
local function traceDoorPhysics(bus, player, id)
    -- Fixed segments across both leaves; a nearby body panel is a control.
    -- Independent of camera aim, so looking away does not move the probes.
    local camera = doorRead(function()
        local system = Game.GetCameraSystem()
        local forward, origin = system:GetActiveCameraForward(), player:GetWorldPosition()
        local target = doorWorldPoint(bus, 1.23, 4.46, 1.10)
        local dx, dy, dz = target.x-origin.x, target.y-origin.y, target.z-origin.z
        local length = math.sqrt(dx*dx+dy*dy+dz*dz)
        return string.format("forward=%.3f,%.3f,%.3f playerToDoorDot=%.3f", forward.x, forward.y,
            forward.z, (dx*forward.x+dy*forward.y+dz*forward.z)/math.max(length, 0.001))
    end)
    local results = {}
    for _, probe in ipairs({{name="leafA", y=4.22}, {name="leafB", y=4.68}, {name="bodyControl", y=3.30}}) do
        for _, group in ipairs({"Vehicle", "Dynamic", "Static"}) do
            results[#results+1] = probe.name .. "/" .. group .. "=" .. doorRead(function()
                local hit, trace = Game.GetSpatialQueriesSystem():SyncRaycastByCollisionGroup(
                    doorWorldPoint(bus, 2.05, probe.y, 1.10),
                    doorWorldPoint(bus, 0.65, probe.y, 1.10), group, false, false)
                if not hit then return "miss" end
                -- Optional RedHotTools inspection supplies actual physics proxy/shape IDs.
                local detail = doorRead(function()
                    local target = Game.GetWorldInspector():GetPhysicsTraceObject(trace)
                    if not target.resolved then return "unresolved" end
                    return "entity:" .. tostring(target.entity:GetEntityID().hash)
                        .. ",component:" .. tostring(target.component:GetName())
                        .. ",proxy:" .. tostring(target.proxyID)
                        .. ",actor:" .. tostring(target.actorIndex)
                        .. ",shape:" .. tostring(target.shapeIndex)
                        .. ",distance:" .. tostring(target.distance)
                end)
                return "hit{" .. detail .. "}"
            end)
        end
    end
    print("[NCTC Doors D3 physics] bus=" .. id .. " camera=" .. camera .. " " .. table.concat(results, " | "))
end
local function traceDoors(bus, player, dt, distance, mounted, inside, allowed)
    doorTrace.elapsed = doorTrace.elapsed + (tonumber(dt) or 0)
    local id = tostring(bus:GetEntityID().hash)
    local fresh = id ~= doorTrace.id
    local state = doorRead(function() return bus:GetVehiclePS():GetDoorState(EVehicleDoor.seat_front_right) end)
    local desired = allowed and math.abs(bus:GetCurrentSpeed()) <= 1.00 and (mounted or distance < 10.00)
    local key = state .. ":" .. tostring(desired) .. ":" .. tostring(inside)
    if not fresh and key == doorTrace.state and doorTrace.elapsed < (distance < 12 and 0.25 or 5) then return end
    doorTrace.id, doorTrace.state, doorTrace.elapsed = id, key, 0
    local p = localPosition(bus, player)
    local door = bus:FindComponentByName(CName.new("door"))
    print("[NCTC Doors D3] bus=" .. id .. " state=" .. state
        .. " desiredOpen=" .. tostring(desired) .. " atStop=" .. tostring(allowed)
        .. " mounted=" .. tostring(mounted) .. " cabinZone=" .. tostring(inside)
        .. " speed=" .. string.format("%.3f", bus:GetCurrentSpeed())
        .. " distance=" .. string.format("%.3f", distance)
        .. " playerLocal=" .. string.format("%.3f,%.3f,%.3f", p.x, p.y, p.z)
        .. " component=" .. tostring(door ~= nil)
        .. " enabled=" .. doorRead(function() return door:IsEnabled() end))
    if fresh then
        for _, field in ipairs({"simulationType", "useResourceSimulationType", "startInactive", "filterDataSource", "filterData", "mesh", "parentTransform", "skinning"}) do
            print("[NCTC Doors D3 component] " .. field .. "=" .. doorRead(function() return door[field] end))
        end
    end
    if distance < 12 then traceDoorPhysics(bus, player, id) end
end

local function sameSeats(left, right)
    if #left ~= #right then return false end
    for i = 1, #left do if left[i].id ~= right[i].id then return false end end
    return true
end

local function vectorText(value)
    if not value then return "none" end
    return string.format("(%.3f, %.3f, %.3f)", value.x, value.y, value.z)
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

local function makeHubChoiceHub()
    local hub = gameinteractionsvisListChoiceHubData.new()
    hub.title, hub.activityState, hub.hubPriority, hub.id = "NCTC — Choose line", gameinteractionsvisEVisualizerActivityState.Active, 1, 77902
    local choices = {}
    for _, service in ipairs(NCBN.hubChoices) do
        local choiceType = gameinteractionsChoiceTypeWrapper.new()
        choiceType:SetType(gameinteractionsChoiceType.Selected)
        local choice = gameinteractionsvisListChoiceData.new()
        choice.localizedName, choice.inputActionName, choice.type = "Wait for line " .. tostring(service.line), CName.new("None"), choiceType
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

local function hideHubChoice()
    if not NCBN.hubChoiceVisible then return end
    NCBN.hubChoiceVisible, NCBN.hubChoiceHub, NCBN.hubChoices = false, nil, {}
    if NCBN.interactionUI then
        local defs = GetAllBlackboardDefs().UIInteractions
        local blackboard = Game.GetBlackboardSystem():Get(defs)
        -- A line hub is injected by CET, so closing it also has to clear the
        -- vanilla UI's active-hub selection.  Replacing only DialogChoiceHubs
        -- leaves the list widget focused on the now removed hub.
        blackboard:SetInt(defs.ActiveChoiceHubID, 0)
        NCBN.interactionUI:OnDialogsData(blackboard:GetVariant(defs.DialogChoiceHubs))
        NCBN.interactionUI:OnInteractionsChanged()
        NCBN.interactionUI:UpdateListBlackboard()
        NCBN.interactionUI:OnDialogsActivateHub(0)
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

local function showHubChoice()
    if not NCBN.interactionUI or #NCBN.hubChoices == 0 then return end
    NCBN.hubChoiceHub = makeHubChoiceHub()
    NCBN.hubChoiceVisible = true
    local defs = GetAllBlackboardDefs().UIInteractions
    local blackboard = Game.GetBlackboardSystem():Get(defs)
    blackboard:SetInt(defs.ActiveChoiceHubID, NCBN.hubChoiceHub.id)
    local data = blackboard:GetVariant(defs.DialogChoiceHubs)
    NCBN.interactionUI:OnDialogsSelectIndex(NCBN.selectedHubLine)
    NCBN.interactionUI:OnDialogsData(data)
    NCBN.interactionUI:OnInteractionsChanged()
    NCBN.interactionUI:UpdateListBlackboard()
    NCBN.interactionUI:OnDialogsActivateHub(NCBN.hubChoiceHub.id)
end

local function updateHubChoice()
    -- Hub line selection is now a native Redscript interaction. CET retains
    -- only the passenger-seat UI and must not reopen a legacy saved menu.
    return
end

local function mountPassenger(seat)
    local player, bus = Game.GetPlayer(), findServiceBus()
    if not player or not bus or player:GetMountedVehicle() ~= nil or not seat or not isSeatFree(bus, seat.id) then return end
    local data, slot, info, request = MountEventData.new(), MountingSlotId.new(), MountingInfo.new(), MountingRequest.new()
    data.isInstant, data.slotName, data.mountParentEntityId = false, seat.id, bus:GetEntityID()
    slot.id = seat.id
    info.childId, info.parentId, info.slotId = player:GetEntityID(), bus:GetEntityID(), slot
    request.lowLevelMountingInfo, request.mountData = info, data
    -- This interaction only ever targets the two rear passenger workspots.
    -- Remember that provenance until the game confirms V is mounted; querying
    -- the workspot back from the Mahir is unreliable in CET.
    NCBN.passengerMountRequested = true
    NCBN.mountRequestDeadline = os.clock() + 5.0
    print("[NCBN] Mount requested seat=" .. seat.id
        .. " atStop=" .. tostring(getFact("nctc_service_bus_at_stop"))
        .. " speed=" .. string.format("%.2f", bus:GetCurrentSpeed()))
    -- This is an edge-triggered service request, not a mirror of the game's
    -- unreliable Mahir mounted-slot state. The transit loop acknowledges it
    -- exactly once after allowing the seating animation to complete.
    setFact("nctc_passenger_departure_requested", 1)
    Game.GetMountingFacility():Mount(request)
    hideChoice()
end

registerForEvent("onInit", function()
    -- This is the actual vanilla entry point for a pedestrian struck by a car.
    -- Crucially, OnCarHitPlayer still carries the real carId; the damage code
    -- later replaces both source and instigator with the player itself.
    ObserveBefore("PlayerPuppet", "OnCarHitPlayer", function(player, evt)
        if not player or not evt then return end
        local bus = findServiceBus()
        local function idText(value)
            local ok, valueText = pcall(function() return EntityID.ToDebugString(value) end)
            return ok and tostring(valueText) or tostring(value)
        end
        local car = nil
        pcall(function() car = Game.FindEntityByID(evt.carId) end)
        local p = bus and localPosition(bus, player) or nil
        local sameBus = false
        if bus then
            pcall(function() sameBus = bus:GetEntityID().hash == evt.carId.hash end)
        end
        print("[NCTC CarHit Pre]"
            .. " carId=" .. idText(evt.carId)
            .. " activeBus=" .. (bus and idText(bus:GetEntityID()) or "none")
            .. " sameBus=" .. tostring(sameBus)
            .. " resolvedCar=" .. tostring(car ~= nil)
            .. " hitDirection=" .. tostring(evt.hitDirection)
            .. " separationImpulse=" .. tostring(evt.seperationImpulse)
            .. " localPosition=" .. (p and string.format("x=%.3f,y=%.3f,z=%.3f", p.x, p.y, p.z) or "none")
            .. " insideGeometry=" .. tostring(bus ~= nil and playerIsInside(bus, player))
            .. " insideFact=" .. tostring(getFact("nctc_player_in_service_bus")))
    end)

    -- Capture the native request before VehicleKnockdown is applied. This
    -- preserves the source arguments that PlayerPuppet's later callback lacks.
    ObserveBefore("StatusEffectSystem", "ApplyStatusEffect", function(_, targetID, statusEffectID, instigatorStaticDataID, instigatorEntityID)
        local okStatus, statusText = pcall(function() return TweakDBID.ToStringDEBUG(statusEffectID) end)
        statusText = okStatus and tostring(statusText) or tostring(statusEffectID)
        if not string.find(statusText, "VehicleKnockdown", 1, true) then return end

        local player, bus = Game.GetPlayer(), findServiceBus()
        local function idText(value)
            local ok, valueText = pcall(function() return EntityID.ToDebugString(value) end)
            return ok and tostring(valueText) or tostring(value)
        end
        local function recordText(entity)
            if not entity then return "none" end
            local ok, value = pcall(function() return TweakDBID.ToStringDEBUG(entity:GetRecordID()) end)
            return ok and tostring(value) or "unknown"
        end
        local instigator = nil
        pcall(function() instigator = Game.FindEntityByID(instigatorEntityID) end)
        print("[NCTC Collision PreApply] VehicleKnockdown"
            .. " target=" .. idText(targetID)
            .. " status=" .. statusText
            .. " instigatorStaticData=" .. tostring(instigatorStaticDataID)
            .. " instigator=" .. idText(instigatorEntityID)
            .. " instigatorRecord=" .. recordText(instigator)
            .. " player=" .. (player and idText(player:GetEntityID()) or "none")
            .. " bus=" .. (bus and idText(bus:GetEntityID()) or "none")
            .. " busRecord=" .. recordText(bus)
            .. " insideFact=" .. tostring(getFact("nctc_player_in_service_bus")))
    end)

    Observe("InteractionUIBase", "OnInitialize", function(this) NCBN.interactionUI = this end)
    Observe("InteractionUIBase", "OnDialogsData", function(this) NCBN.interactionUI = this end)
    Observe("InteractionUIBase", "OnUninitialize", function(this) if NCBN.interactionUI == this then NCBN.interactionUI = nil end end)
    Override("InteractionUIBase", "OnDialogsData", function(_, value, wrapped)
        if (NCBN.choiceVisible and NCBN.choiceHub) or (NCBN.hubChoiceVisible and NCBN.hubChoiceHub) then
            local data = FromVariant(value)
            -- FromVariant properties are copied. Reassigning the modified
            -- array is required or the HUD never receives our seat choice.
            local hubs = data.choiceHubs
            if NCBN.choiceVisible and NCBN.choiceHub then table.insert(hubs, NCBN.choiceHub) end
            if NCBN.hubChoiceVisible and NCBN.hubChoiceHub then table.insert(hubs, NCBN.hubChoiceHub) end
            data.choiceHubs = hubs
            wrapped(ToVariant(data))
        else wrapped(value) end
    end)
    Override("InteractionUIBase", "OnDialogsSelectIndex", function(_, index, wrapped)
        if NCBN.hubChoiceVisible then return wrapped(NCBN.selectedHubLine) end
        wrapped(NCBN.choiceVisible and NCBN.selectedSeat or index)
    end)
    Override("dialogWidgetGameController", "OnDialogsActivateHub", function(_, id, wrapped)
        if NCBN.hubChoiceVisible and NCBN.hubChoiceHub then return wrapped(NCBN.hubChoiceHub.id) end
        return wrapped(NCBN.choiceVisible and NCBN.choiceHub and NCBN.choiceHub.id or id)
    end)
    Observe("PlayerPuppet", "OnAction", function(_, action, consumer)
        if NCBN.inputLocked or action:GetType(action).value ~= "BUTTON_PRESSED" or action:GetValue(action) <= 0 then return end
        local name = action:GetName(action).value
        if NCBN.hubChoiceVisible and name == "ChoiceApply" then
            NCBN.inputLocked = true; consumer:Consume()
            requestHubService(NCBN.hubChoices[NCBN.selectedHubLine + 1])
            hideHubChoice()
        elseif NCBN.hubChoiceVisible and (name == "ChoiceScrollUp" or name == "ChoiceScrollDown") then
            NCBN.inputLocked = true; consumer:Consume()
            NCBN.selectedHubLine = (NCBN.selectedHubLine + (name == "ChoiceScrollUp" and 1 or -1)) % #NCBN.hubChoices
            showHubChoice()
        elseif NCBN.choiceVisible and name == "ChoiceApply" then
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

registerForEvent("onUpdate", function(dt)
    NCBN.inputLocked = false
    local player, bus = Game.GetPlayer(), findServiceBus()
    if not player or not bus then
        doorTrace.id, doorTrace.state, doorTrace.elapsed = nil, nil, 0
        NCBN.passengerMountRequested = false
        NCBN.mountRequestDeadline = 0
        NCBN.wasMounted = false
        NCBN.wasInside = false
        NCBN.lastInsideLocal = nil
        setFact("nctc_player_in_service_bus", 0)
        signalTransitSystem(false)
        hideChoice()
        return
    end
    local distance = Vector4.Distance(player:GetWorldPosition(), bus:GetWorldPosition())
    local isMounted = player:GetMountedVehicle() ~= nil
    local insideNow = playerIsInside(bus, player)
    -- Exact validated Drive a Bus / NCBN 0.0.13 door behaviour.
    -- Proximity may open the door only during an official NCTC stop. When the
    -- route loop revokes this fact, CET must allow the door to stay closed so
    -- the departure state can advance.
    local boardingAllowed = getFact("nctc_service_bus_at_stop") == 1
    local traceOk, traceError = pcall(traceDoors, bus, player, dt, distance, isMounted, insideNow, boardingAllowed)
    if not traceOk and not doorTrace.failed then
        doorTrace.failed = true
        print("[NCTC Doors D2] diagnostic error (gameplay unchanged): " .. tostring(traceError))
    end
    -- At a scheduled stop the door stays open for boarding and alighting,
    -- including while V is already mounted in a rear passenger workspot.
    setBoardingDoor(bus, boardingAllowed and math.abs(bus:GetCurrentSpeed()) <= 1.00 and (isMounted or distance < 10.00))

    if isMounted then
        local slot = bus:GetSlotIdForMountedObject(player)
        local slotName = slot and slot.value or "unknown"
        -- The mounted vehicle wrapper is not stable for these passenger
        -- workspots. The slot belongs to this exact bus and is the reliable
        -- proof that V is seated in one of NCTC's rear passenger places.
        local aboard = NCBN.passengerMountRequested or passengerSlots[slotName] == true
        NCBN.wasMounted = true
        setFact("nctc_player_in_service_bus", aboard and 1 or 0)
        signalTransitSystem(aboard)
        if slotName ~= NCBN.lastMountedSlot then
            NCBN.lastMountedSlot = slotName
            print("[NCBN] Player mounted slot: " .. slotName .. (passengerSlots[slotName] and " (passenger)" or " (forbidden)"))
            print("[NCBN] Mount confirmed atStop=" .. tostring(getFact("nctc_service_bus_at_stop"))
                .. " speed=" .. string.format("%.2f", bus:GetCurrentSpeed())
                .. " departureRequest=" .. tostring(getFact("nctc_passenger_departure_requested")))
        end
        hideChoice()
        return
    end
    -- Mounting is asynchronous. Do not clear the provenance on the frame
    -- between Mount(request) and GetMountedVehicle() becoming valid.
    if NCBN.wasMounted then
        print("[NCBN] Mount ended slot=" .. tostring(NCBN.lastMountedSlot)
            .. " atStop=" .. tostring(getFact("nctc_service_bus_at_stop"))
            .. " speed=" .. string.format("%.2f", bus:GetCurrentSpeed()))
        NCBN.passengerMountRequested = false
        NCBN.mountRequestDeadline = 0
        NCBN.wasMounted = false
    elseif NCBN.passengerMountRequested and os.clock() > NCBN.mountRequestDeadline then
        NCBN.passengerMountRequested = false
        NCBN.mountRequestDeadline = 0
    end
    NCBN.lastMountedSlot = nil
    local inside = insideNow
    local localNow = localPosition(bus, player)
    setFact("nctc_player_in_service_bus", inside and 1 or 0)
    signalTransitSystem(inside)
    if inside ~= NCBN.wasInside then
        local loopLine = getFact("nctc_dev_loop_line")
        local loopStop = getFact("nctc_dev_loop_stop_id")
        local serviceStop = getFact("nctc_dev_loop_service_stop_id")
        local nextStop = getFact("nctc_dev_loop_next_stop_id")
        NCBN.wasInside = inside
        print((inside and "[NCBN] Player entered the walkable cabin." or "[NCBN] Player left the walkable cabin.")
            .. " atStop=" .. tostring(getFact("nctc_service_bus_at_stop"))
            .. " speed=" .. string.format("%.2f", bus:GetCurrentSpeed())
            .. " departureRequest=" .. tostring(getFact("nctc_passenger_departure_requested"))
            .. " route=L" .. tostring(loopLine) .. " stop=" .. tostring(loopStop)
            .. " serviceStop=" .. tostring(serviceStop) .. " next=" .. tostring(nextStop)
            .. " localNow=" .. vectorText(localNow)
            .. " localPrevious=" .. vectorText(NCBN.lastInsideLocal)
            .. " playerWorld=" .. vectorText(player:GetWorldPosition())
            .. " busWorld=" .. vectorText(bus:GetWorldPosition()))
    end
    if inside then NCBN.lastInsideLocal = localNow end
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
