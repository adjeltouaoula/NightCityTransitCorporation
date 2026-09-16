local PREFIX = "[NCTC SERVICE ID DIAG]"

local records = {
    "Vehicle.nctc_service_mahir_mt28_coach",
    "Vehicle.v_mahir_mt28_coach",
    "Vehicle.v_standard2_villefort_cortes_delamain",
    "Vehicle.v_standard2_villefort_cortes_delamain_player"
}

local fields = {
    "affiliation",
    "type",
    "archetypeName",
    "tags",
    "visualTags",
    "crowdMemberSettings",
    "randomPassengers",
    "vehBehaviorData",
    "vehDataPackage",
    "persistentName",
    "objectActions",
    "priority",
    "vehicleUIData",
    "entityTemplatePath"
}

local function safe(fn)
    local ok, value = pcall(fn)
    if ok then return value end
    return nil
end

local function stringifyScalar(value)
    if value == nil then return "<nil>" end

    local asName = safe(function() return NameToString(value) end)
    if type(asName) == "string" and asName ~= "" then
        return asName
    end

    local asTdbid = safe(function() return TweakDBID.ToStringDEBUG(value) end)
    if type(asTdbid) == "string" and asTdbid ~= "" then
        return asTdbid
    end

    return tostring(value)
end

local function stringify(value)
    if value == nil then return "<nil>" end

    local count = safe(function() return #value end)
    if type(count) == "number" and count > 0 then
        local out = {}
        for i = 1, count do
            out[#out + 1] = stringifyScalar(value[i])
        end
        return "[" .. table.concat(out, ", ") .. "]"
    end

    return stringifyScalar(value)
end

local function getFlat(path)
    return safe(function() return TweakDB:GetFlat(path) end)
end

local function dumpRecord(record)
    print(PREFIX .. " RECORD " .. record)
    for _, field in ipairs(fields) do
        local path = record .. "." .. field
        local value = getFlat(path)
        print(PREFIX .. " " .. field .. "=" .. stringify(value))
    end
end

registerForEvent("onInit", function()
    print(PREFIX .. " loaded; read-only TweakDB comparison")
    for _, record in ipairs(records) do
        dumpRecord(record)
    end
    print(PREFIX .. " done")
end)
