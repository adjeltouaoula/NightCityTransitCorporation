local TAG = "NCTC.ServiceBus"
local pendingSnapshots = {}

local function safe(label, fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return "<" .. label .. " error: " .. tostring(value) .. ">"
end

local function sameEntity(left, right)
    if not left or not right then return false end
    local ok, same = pcall(function()
        return left:GetEntityID().hash == right:GetEntityID().hash
    end)
    return ok and same or false
end

local function findServiceBus()
    local dynamic = Game.GetDynamicEntitySystem()
    if not dynamic then return nil end
    local ids = dynamic:GetTaggedIDs(TAG)
    if not ids or #ids == 0 then return nil end
    return Game.FindEntityByID(ids[1])
end

local function cnameText(value)
    if value == nil then return "nil" end
    local text = safe("cname", function() return NameToString(value) end)
    if type(text) == "string" and string.sub(text, 1, 1) ~= "<" and text ~= "" then
        return text
    end
    return tostring(value)
end

local function boolText(value)
    if value == true then return "true" end
    if value == false then return "false" end
    return tostring(value)
end

local function isDriverSlot(slot)
    if slot == nil then return "nil" end
    return safe("IsDriverSlot", function()
        return VehicleComponent.IsDriverSlot(slot)
    end)
end

local function getFact(name)
    local quests = Game.GetQuestsSystem()
    if not quests then return "no-quests" end
    return safe("fact", function() return quests:GetFact(CName.new(name)) end)
end

local function getVehicleFromComponent(component)
    if not component then return nil end
    local vehicle = safe("GetVehicle", function() return component:GetVehicle() end)
    if type(vehicle) == "string" then return nil end
    return vehicle
end

local function eventBelongsToServiceBus(component, evt)
    local bus = findServiceBus()
    if not bus then return false, nil, nil end
    local vehicle = getVehicleFromComponent(component)
    if vehicle and sameEntity(vehicle, bus) then return true, vehicle, bus end

    if evt and evt.character then
        local player = Game.GetPlayer()
        if player and sameEntity(evt.character, player) then
            local mounted = safe("GetMountedVehicle", function() return player:GetMountedVehicle() end)
            if type(mounted) ~= "string" and mounted and sameEntity(mounted, bus) then
                return true, bus, bus
            end
        end
    end

    return false, vehicle, bus
end

local function snapshot(stage, component, evt)
    local bus = findServiceBus()
    if not bus then return end

    local vehicle = getVehicleFromComponent(component) or bus
    if component and vehicle and not sameEntity(vehicle, bus) then return end

    local player = Game.GetPlayer()
    if not player then return end

    local evtSlot = evt and evt.slotID or nil
    local evtCharacterIsPlayer = evt and evt.character and sameEntity(evt.character, player) or false
    local evtMounting = evt and evt.isMounting or nil

    local facilitySlot = nil
    local facilityParentMatchesBus = nil
    local mountingInfo = safe("GetMountingInfoSingleWithObjects", function()
        return Game.GetMountingFacility():GetMountingInfoSingleWithObjects(player)
    end)
    if type(mountingInfo) ~= "string" and mountingInfo then
        facilitySlot = mountingInfo.slotId and mountingInfo.slotId.id or nil
        facilityParentMatchesBus = safe("mount parent", function()
            return mountingInfo.parentId.hash == bus:GetEntityID().hash
        end)
    end

    local mountedVehicle = safe("GetMountedVehicle", function() return player:GetMountedVehicle() end)
    local mountedVehicleMatchesBus = type(mountedVehicle) ~= "string" and mountedVehicle ~= nil and sameEntity(mountedVehicle, bus)

    local ps = safe("GetVehiclePS", function() return bus:GetVehiclePS() end)
    local isPlayerVehicle = "no-ps"
    local isStolen = "no-ps"
    local questModified = "no-ps"
    if type(ps) ~= "string" and ps then
        isPlayerVehicle = safe("GetIsPlayerVehicle", function() return ps:GetIsPlayerVehicle() end)
        isStolen = safe("GetIsStolen", function() return ps:GetIsStolen() end)
        questModified = safe("GetHasStateBeenModifiedByQuest", function() return ps:GetHasStateBeenModifiedByQuest() end)
    end

    local isQuest = safe("IsQuest", function() return bus:IsQuest() end)
    local record = safe("record", function() return TweakDBID.ToStringDEBUG(bus:GetRecordID()) end)

    print("[NCTC MOUNT DIAG]"
        .. " stage=" .. tostring(stage)
        .. " eventMounting=" .. tostring(evtMounting)
        .. " eventCharacterIsPlayer=" .. boolText(evtCharacterIsPlayer)
        .. " eventSlot=" .. cnameText(evtSlot)
        .. " eventIsDriver=" .. boolText(isDriverSlot(evtSlot))
        .. " facilitySlot=" .. cnameText(facilitySlot)
        .. " facilityIsDriver=" .. boolText(isDriverSlot(facilitySlot))
        .. " facilityParentIsBus=" .. boolText(facilityParentMatchesBus)
        .. " mountedVehicleIsBus=" .. boolText(mountedVehicleMatchesBus)
        .. " playerVehicle=" .. boolText(isPlayerVehicle)
        .. " stolen=" .. boolText(isStolen)
        .. " questModified=" .. boolText(questModified)
        .. " isQuest=" .. boolText(isQuest)
        .. " aboardFact=" .. tostring(getFact("nctc_player_in_service_bus"))
        .. " record=" .. tostring(record))
end

local function scheduleSettledSnapshots()
    local now = os.clock()
    pendingSnapshots = {
        { at = now + 0.10, label = "settled+0.10s" },
        { at = now + 0.50, label = "settled+0.50s" },
        { at = now + 1.00, label = "settled+1.00s" }
    }
end

local function installObserver(kind, methodName, callback)
    local ok, err = pcall(function()
        if kind == "before" then
            ObserveBefore("VehicleComponent", methodName, callback)
        else
            ObserveAfter("VehicleComponent", methodName, callback)
        end
    end)
    print("[NCTC MOUNT DIAG] observer=" .. kind .. ":" .. methodName
        .. " installed=" .. tostring(ok)
        .. (ok and "" or " error=" .. tostring(err)))
end

registerForEvent("onInit", function()
    print("[NCTC MOUNT DIAG] loaded; diagnostics only, no mount state is modified")

    installObserver("before", "OnVehicleStartedMountingEvent", function(component, evt)
        local relevant = eventBelongsToServiceBus(component, evt)
        if relevant then snapshot("started-before", component, evt) end
    end)

    installObserver("after", "OnVehicleStartedMountingEvent", function(component, evt)
        local relevant = eventBelongsToServiceBus(component, evt)
        if relevant then snapshot("started-after", component, evt) end
    end)

    installObserver("before", "OnVehicleFinishedMountingEvent", function(component, evt)
        local relevant = eventBelongsToServiceBus(component, evt)
        if relevant then snapshot("finished-before", component, evt) end
    end)

    installObserver("after", "OnVehicleFinishedMountingEvent", function(component, evt)
        local relevant = eventBelongsToServiceBus(component, evt)
        if relevant then
            snapshot("finished-after", component, evt)
            if evt and evt.isMounting and evt.character and sameEntity(evt.character, Game.GetPlayer()) then
                scheduleSettledSnapshots()
            end
        end
    end)
end)

registerForEvent("onUpdate", function()
    if #pendingSnapshots == 0 then return end
    local now = os.clock()
    local remaining = {}
    for _, item in ipairs(pendingSnapshots) do
        if now >= item.at then
            snapshot(item.label, nil, nil)
        else
            table.insert(remaining, item)
        end
    end
    pendingSnapshots = remaining
end)
