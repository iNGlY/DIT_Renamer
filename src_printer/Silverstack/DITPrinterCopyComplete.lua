-- DIT Printer 0.1: Silverstack Backup Post Step
--
-- Attach only to the backup activity that should emit the label. Do not attach
-- it to a Verify activity or a combined Backup+Verify activity when the label
-- must be available immediately after copying.

local bridgePath = "/Applications/DIT Printer.app/Contents/Helpers/DITPrinterBridge"

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

local function callString(object, methodNames)
    if object == nil then return nil end
    for _, methodName in ipairs(methodNames) do
        local found, method = pcall(function() return object[methodName] end)
        if found and type(method) == "function" then
            local ok, value = pcall(method, object)
            if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
        end
    end
    return nil
end

local function binNameFor(asset)
    local metadata = nil
    if asset ~= nil then
        local ok, value = pcall(function() return asset:metadata() end)
        if ok then metadata = value end
    end
    return callString(metadata, { "getBinName", "getBin", "getBinPath" })
        or callString(asset, { "getBinName", "getBin", "getName" })
        or "(Silverstack Bin name unavailable)"
end

local function lastAssetNameFor(assets)
    local lastAsset = assets[#assets]
    local value = callString(lastAsset, { "getFileName", "getFilename", "getName", "getPath" })
    if value == nil then return "(Silverstack final asset unavailable)" end
    return value:match("([^/]+)$") or value
end

local function volumePathFor(resource)
    local volume = nil
    if resource ~= nil then
        local ok, value = pcall(function() return resource:getVolume() end)
        if ok then volume = value end
    end
    return callString(volume, { "getPath", "getMountPath" })
        or callString(resource, { "getPath" })
end

function onFinish(assets, resources, workingPath, success)
    if not success then
        print("DIT Printer: backup activity failed; label skipped")
        return "DIT Printer skipped: copy failed"
    end
    if #assets == 0 then
        return "DIT Printer skipped: no assets supplied by post step"
    end

    local binName = binNameFor(assets[1])
    local lastAssetName = lastAssetNameFor(assets)
    local sourceVolumePath = volumePathFor(resources and resources[1])
    local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local jobID = workingPath .. "|" .. binName .. "|" .. lastAssetName
    local manifestPath = workingPath .. "/dit-printer-copy-complete.json"
    local file = assert(io.open(manifestPath, "w"))
    file:write("{\n")
    file:write("  \"job_id\": \"", jsonEscape(jobID), "\",\n")
    file:write("  \"bin_name\": \"", jsonEscape(binName), "\",\n")
    file:write("  \"last_asset_name\": \"", jsonEscape(lastAssetName), "\",\n")
    if sourceVolumePath ~= nil then
        file:write("  \"source_volume_path\": \"", jsonEscape(sourceVolumePath), "\",\n")
    end
    file:write("  \"signal_source\": \"Silverstack Copy Job complete\",\n")
    file:write("  \"copy_completed_at\": \"", now, "\"\n")
    file:write("}\n")
    file:close()

    local result = os.execute(shellQuote(bridgePath) .. " --manifest " .. shellQuote(manifestPath))
    if result ~= true and result ~= 0 then
        error("DIT Printer bridge failed: " .. tostring(result))
    end
    return "DIT Printer queued: " .. manifestPath
end
