-- DIT Printer + ParaShoot: Copy Job Post Step with Verify included.
--
-- Attach this one script to the Copy Job whose Verify activity is configured
-- as Included. Configure Input Files in this order: source card, destination 1.

local printBridgePath = "/Applications/DIT Printer.app/Contents/Helpers/DITPrinterBridge"
local eraseBridgePath = "/Applications/DIT Printer.app/Contents/Helpers/ParaShootEraseBridge"
local sourceResourceIndex = 1
local verifiedDestinationResourceIndex = 2

-- JSON escaping keeps manifest data separate from shell command construction.
local function jsonEscape(value)
    local text = tostring(value or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub("\"", "\\\"")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    return text
end

-- Shell quoting prevents paths and names from changing the launched command.
local function shellQuote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

-- Safely call a version-dependent Silverstack getter.
local function callValue(object, methodName)
    if object == nil then return nil end
    local found, method = pcall(function() return object[methodName] end)
    if not found or type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object)
    return ok and value or nil
end

-- Try several text getters without assuming a particular Silverstack version.
local function callString(object, methodNames)
    for _, methodName in ipairs(methodNames) do
        local value = callValue(object, methodName)
        if value ~= nil and tostring(value) ~= "" then return tostring(value) end
    end
    return nil
end

-- Resolve the mounted volume path rather than a nested asset path.
local function volumePathFor(resource)
    local volume = callValue(resource, "getVolume")
    if type(volume) == "string" and volume ~= "" then return volume end
    local volumePath = callString(volume, { "getPath", "getMountPath" })
    if volumePath ~= nil then return volumePath end
    return callString(resource, { "getPath" })
end

-- Read label fields from Silverstack; the UI remains the fallback review step.
local function binNameFor(asset)
    local metadata = callValue(asset, "metadata")
    return callString(metadata, { "getBinName", "getBin", "getBinPath" })
        or callString(asset, { "getBinName", "getBin", "getName" })
        or "(Silverstack Bin name unavailable)"
end

local function lastAssetNameFor(assets)
    local value = callString(assets[#assets], { "getFileName", "getFilename", "getName", "getPath" })
    if value == nil then return "(Silverstack final asset unavailable)" end
    return value:match("([^/]+)$") or value
end

-- Run each bridge in the background so the two completion signals are emitted
-- from the same successful Copy Job without making Silverstack wait for erase.
local function launchBridge(bridgePath, manifestPath, logPath)
    local command = "/usr/bin/nohup " .. shellQuote(bridgePath)
        .. " --manifest " .. shellQuote(manifestPath)
        .. " > " .. shellQuote(logPath) .. " 2>&1 &"
    local result = os.execute(command)
    return result == true or result == 0
end

function onFinish(assets, resources, workingPath, success)
    if not success then
        return "DIT Printer / ParaShoot skipped: Copy Job verification failed"
    end
    if #assets == 0 then
        return "DIT Printer / ParaShoot skipped: no assets supplied"
    end

    local cardPath = volumePathFor(resources[sourceResourceIndex])
    local destinationPath = volumePathFor(resources[verifiedDestinationResourceIndex])
    if cardPath == nil or destinationPath == nil then
        return "DIT Printer / ParaShoot skipped: configure Source then Destination 1 Input Files"
    end

    local binName = binNameFor(assets[1])
    local lastAssetName = lastAssetNameFor(assets)
    local completedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local jobID = workingPath .. "|" .. cardPath .. "|" .. destinationPath

    local printManifestPath = workingPath .. "/dit-printer-copy-verify-complete.json"
    local printManifest = assert(io.open(printManifestPath, "w"))
    printManifest:write("{\n")
    printManifest:write("  \"job_id\": \"", jsonEscape(jobID .. "|print"), "\",\n")
    printManifest:write("  \"bin_name\": \"", jsonEscape(binName), "\",\n")
    printManifest:write("  \"last_asset_name\": \"", jsonEscape(lastAssetName), "\",\n")
    printManifest:write("  \"source_volume_path\": \"", jsonEscape(cardPath), "\",\n")
    printManifest:write("  \"signal_source\": \"Silverstack Copy Job (Verify Included)\",\n")
    printManifest:write("  \"copy_completed_at\": \"", completedAt, "\"\n")
    printManifest:write("}\n")
    printManifest:close()

    local eraseManifestPath = workingPath .. "/parashoot-copy-verify-erase.json"
    local eraseManifest = assert(io.open(eraseManifestPath, "w"))
    eraseManifest:write("{\n")
    eraseManifest:write("  \"job_id\": \"", jsonEscape(jobID .. "|erase"), "\",\n")
    eraseManifest:write("  \"card_path\": \"", jsonEscape(cardPath), "\",\n")
    eraseManifest:write("  \"verified_destination_path\": \"", jsonEscape(destinationPath), "\",\n")
    eraseManifest:write("  \"verified_at\": \"", completedAt, "\"\n")
    eraseManifest:write("}\n")
    eraseManifest:close()

    local printStarted = launchBridge(printBridgePath, printManifestPath, workingPath .. "/dit-printer-bridge.log")
    local eraseStarted = launchBridge(eraseBridgePath, eraseManifestPath, workingPath .. "/parashoot-erase-bridge.log")
    return "DIT Printer queued=" .. tostring(printStarted) .. "; ParaShoot erase launched=" .. tostring(eraseStarted)
end
