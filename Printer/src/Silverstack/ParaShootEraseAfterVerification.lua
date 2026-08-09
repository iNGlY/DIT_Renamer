-- ParaShoot reversible erase after a successful Silverstack Verify activity.
-- Configure Input Files in this order: source card, then the destination that
-- this Verify activity actually verified. Do not attach to a Backup activity.

local bridgePath = "/Applications/DIT Printer.app/Contents/Helpers/ParaShootEraseBridge"
local sourceResourceIndex = 1
local verifiedDestinationResourceIndex = 2

local function jsonEscape(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub("\"", "\\\"")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    return text
end

local function shellQuote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

local function callValue(object, methodName)
    if object == nil then return nil end
    local found, method = pcall(function() return object[methodName] end)
    if not found or type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object)
    return ok and value or nil
end

local function pathFor(resource)
    local volume = callValue(resource, "getVolume")
    if type(volume) == "string" and volume ~= "" then return volume end
    local volumePath = callValue(volume, "getPath") or callValue(volume, "getMountPath")
    if volumePath ~= nil and tostring(volumePath) ~= "" then return tostring(volumePath) end
    local path = callValue(resource, "getPath")
    return path and tostring(path) or nil
end

function onFinish(assets, resources, workingPath, success)
    if not success then
        return "ParaShoot erase skipped: Verify activity failed"
    end

    local cardPath = pathFor(resources[sourceResourceIndex])
    local destinationPath = pathFor(resources[verifiedDestinationResourceIndex])
    if cardPath == nil or destinationPath == nil then
        return "ParaShoot erase skipped: configure Source then verified Destination Input Files"
    end

    local manifestPath = workingPath .. "/parashoot-verified-erase.json"
    local jobID = workingPath .. "|" .. cardPath .. "|" .. destinationPath
    local file = assert(io.open(manifestPath, "w"))
    file:write("{\n")
    file:write("  \"job_id\": \"", jsonEscape(jobID), "\",\n")
    file:write("  \"card_path\": \"", jsonEscape(cardPath), "\",\n")
    file:write("  \"verified_destination_path\": \"", jsonEscape(destinationPath), "\",\n")
    file:write("  \"verified_at\": \"", os.date("!%Y-%m-%dT%H:%M:%SZ"), "\"\n")
    file:write("}\n")
    file:close()

    local result = os.execute(shellQuote(bridgePath) .. " --manifest " .. shellQuote(manifestPath))
    if result ~= true and result ~= 0 then
        print("ParaShoot erase bridge failed; Verify remains successful: " .. tostring(result))
        return "ParaShoot erase failed; see local bridge audit"
    end
    return "ParaShoot erase submitted: " .. manifestPath
end
