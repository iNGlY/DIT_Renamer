-- DIT Printer + ParaShoot: Copy Job Post Step with Verify included.
--
-- [中文审阅说明：本文件的所有中文内容均为 Lua 注释，只供人工审阅；不会参与
-- Silverstack、DIT Printer 或 ParaShoot 的判断、状态传递和命令执行。]
--
-- Attach this one script to the Copy Job whose Verify activity is configured
-- as Included. Configure Input Files in this order: source card, destination 1.
-- [中文审阅说明：仅应挂载在“包含校验”的拷贝任务最后 Post Step。Input Files
-- 顺序固定为源存储卡、已校验的目标盘 1；顺序错误时脚本会跳过自动化。]

local printBridgePath = "/Applications/DIT Printer.app/Contents/Helpers/DITPrinterBridge"
local eraseBridgePath = "/Applications/DIT Printer.app/Contents/Helpers/ParaShootEraseBridge"
local sourceResourceIndex = 1
local verifiedDestinationResourceIndex = 2

-- JSON escaping keeps manifest data separate from shell command construction.
-- [中文审阅说明：此函数只转义写入 JSON 的文本，避免素材名中的引号、换行或反斜杠
-- 破坏 manifest；它不修改原始素材或卷名。]
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
-- [中文审阅说明：此函数只为启动本机桥接器做 shell 安全引用，任何素材路径都不会
-- 被拼接为可执行的 shell 指令。]
local function shellQuote(value)
    return "'" .. tostring(value or ""):gsub("'", "'\\''") .. "'"
end

-- Safely call a version-dependent Silverstack getter.
-- [中文审阅说明：不同 Silverstack 版本的元数据 getter 名称可能不同。调用失败只会
-- 返回空值，脚本不会据此猜测存储卡、目标盘或素材路径。]
local function callValue(object, methodName)
    if object == nil then return nil end
    local found, method = pcall(function() return object[methodName] end)
    if not found or type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object)
    return ok and value or nil
end

-- Try several text getters without assuming a particular Silverstack version.
-- [中文审阅说明：此函数只读取字符串字段；读取不到 Bin 名或文件名时会给出占位文本，
-- 由 DIT Printer 的人工界面复核，不会因此自动擦卡。]
local function callString(object, methodNames)
    for _, methodName in ipairs(methodNames) do
        local value = callValue(object, methodName)
        if value ~= nil and tostring(value) ~= "" then return tostring(value) end
    end
    return nil
end

-- Resolve the mounted volume path rather than a nested asset path.
-- [中文审阅说明：擦除桥接器只接受 /Volumes 下的卷根目录。若 Silverstack 仅提供素材
-- 子目录且无法取得所属卷，后续预检会拒绝该任务，而不是对父目录进行猜测。]
local function volumePathFor(resource)
    local volume = callValue(resource, "getVolume")
    if type(volume) == "string" and volume ~= "" then return volume end
    local volumePath = callString(volume, { "getPath", "getMountPath" })
    if volumePath ~= nil then return volumePath end
    return callString(resource, { "getPath" })
end

-- Read label fields from Silverstack; the UI remains the fallback review step.
-- [中文审阅说明：标签中的 Bin 名和最后素材文件名来自 Silverstack 提供的 assets。
-- assets 的排序必须在现场测试确认；脚本不会用文件修改时间伪造“最后拷贝”顺序。]
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
-- [中文审阅说明：打印桥接器负责写入待打印队列；擦除桥接器会自行完成 ParaShoot
-- 预检和可恢复擦除。nohup + & 只用于后台启动，不代表拷贝或校验成功。]
local function launchBridge(bridgePath, manifestPath, logPath)
    local command = "/usr/bin/nohup " .. shellQuote(bridgePath)
        .. " --manifest " .. shellQuote(manifestPath)
        .. " > " .. shellQuote(logPath) .. " 2>&1 &"
    local result = os.execute(command)
    return result == true or result == 0
end

function onFinish(assets, resources, workingPath, success)
    -- [中文审阅说明：success 仅代表当前包含 Verify 的 Copy Job 成功结束。失败、取消或
    -- 未完成的任务不会发送打印或擦除信号。]
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

    -- [中文审阅说明：两个 manifest 都写入 Silverstack 的工作目录。打印 manifest 只
    -- 创建待打印工作；擦除 manifest 指向已验证的单一目标盘。写入操作不接触存储卡内容。]
    local printManifestPath = workingPath .. "/dit-printer-copy-verify-complete.json"
    local printManifest = assert(io.open(printManifestPath, "w"))
    printManifest:write("{\n")
    printManifest:write("  \"job_id\": \"", jsonEscape(jobID .. "|print"), "\",\n")
    printManifest:write("  \"bin_name\": \"", jsonEscape(binName), "\",\n")
    printManifest:write("  \"last_asset_name\": \"", jsonEscape(lastAssetName), "\",\n")
    printManifest:write("  \"source_volume_path\": \"", jsonEscape(cardPath), "\",\n")
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

    -- [中文审阅说明：以下两次后台启动由同一成功事件发出。启动失败只记录状态文本，
    -- 不会把已完成的 Copy Job/Verify 结果改写为失败。实际擦除成功与否由 ParaShoot
    -- bridge 的审计 JSON 和 .log 文件记录。]
    local printStarted = launchBridge(printBridgePath, printManifestPath, workingPath .. "/dit-printer-bridge.log")
    local eraseStarted = launchBridge(eraseBridgePath, eraseManifestPath, workingPath .. "/parashoot-erase-bridge.log")
    return "DIT Printer queued=" .. tostring(printStarted) .. "; ParaShoot erase launched=" .. tostring(eraseStarted)
end
