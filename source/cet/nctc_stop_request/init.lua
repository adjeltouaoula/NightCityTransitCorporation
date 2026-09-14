-- NCTC stop-request input bridge.
-- Deliberately isolated from nctc_passenger so passenger-seat interaction code
-- remains byte-for-byte untouched by the stop-request control feature.

local function getFact(name)
    local quests = Game.GetQuestsSystem()
    if not quests then return 0 end
    local ok, value = pcall(function() return quests:GetFact(CName.new(name)) end)
    if ok and type(value) == "number" then return value end
    ok, value = pcall(function() return quests:GetFact(name) end)
    if ok and type(value) == "number" then return value end
    return 0
end

local function requestNextStop()
    if getFact("nctc_player_in_service_bus") ~= 1 then return false end
    local container = Game.GetScriptableSystemsContainer()
    if not container then return false end
    local ok, system = pcall(function() return container:Get("NCTC.NCTCTransitSystem") end)
    if not ok or not system then
        ok, system = pcall(function() return container:Get(CName.new("NCTC.NCTCTransitSystem")) end)
    end
    if not ok or not system then return false end
    local requestOk, accepted = pcall(function() return system:RequestNextStop() end)
    if requestOk and accepted then
        print("[NCTC Stop Request] requested stop id=" .. tostring(getFact("nctc_passenger_requested_stop_id")))
    end
    return requestOk and accepted
end

registerForEvent("onInit", function()
    Observe("PlayerPuppet", "OnAction", function(_, action, consumer)
        if not action or not consumer then return end
        local actionType = action:GetType(action).value
        local name = action:GetName(action).value
        if name == "NCTC_RequestNextStop"
            and actionType == "BUTTON_PRESSED"
            and action:GetValue(action) > 0
            and getFact("nctc_player_in_service_bus") == 1 then
            consumer:Consume()
            requestNextStop()
        end
    end)
    print("[NCTC Stop Request] native input bridge initialized.")
end)
