# GP-M325F + Silverstack Lua 自动标签打印方案

检索日期：2026-08-09

## 结论

可行。推荐使用 Silverstack XT/Lab 9.2.0 或更高版本的 **Post Step Script**：拷贝/校验活动完成后，Silverstack 调用 Lua 的 `onFinish(..., success)`；脚本只在 `success == true` 时生成一个小型 manifest，再用 `os.execute()` 启动本机打印桥接程序。桥接程序将标签内容编码为 GP-M325F 支持的 TSPL 指令，并提交给 macOS CUPS 打印队列或已绑定的蓝牙串口。

关键限制是：Silverstack Lua 本身不是打印驱动，也不能直接管理打印队列；GP-M325F 的连接、TSPL 编码、中文字体/二维码和失败重试应放在外部 helper 中。

## 一手资料核验

### Silverstack

- [Pomfort 官方 scripting 仓库](https://github.com/pomfort/silverstack-scripting)确认兼容 Silverstack XT 和 Silverstack Lab。
- 官方 README 写明脚本功能从 Silverstack **9.2.0** 起提供，语言为 **Lua 5.5.0**。
- `onFinish(assets, resources, workingPath, success)` 是 post-step 入口；脚本在活动完成后只执行一次，`success` 表示任务成功或失败。
- Post Step 的 `Input Files` 可以选择 source、destination 1、destination 2 等资源；`Working Path` 会传给 Lua 并被转换为绝对路径。
- 官方 README 明确允许脚本用 `os.execute()` 启动外部工具，但明确说明 scripting 不是 Silverstack headless/API 控制接口，不能由脚本启动或管理 Silverstack workflow。
- [官方 workflow 文档](https://kb.pomfort.com/silverstack/configuring-a-workflow/)确认报告可以作为 activity 的 Post Step，工作流可以包含注册、双目标 backup、transcode、报告等活动。
- [Lua API 参考](https://github.com/pomfort/silverstack-scripting/blob/main/reference/lua-reference.md)提供了 `FileResource:getPath()`、`FileResource:getVolume()`、`Asset:metadata()` 等接口。

### GP-M325F

- [佳博官方 GP-M325F 产品页](https://en.gprinter.net/products_show.asp?lan=zh-en&skin=2&newsid=601492066)确认其为 3-inch portable printer，支持 label/slipform dual mode 和 Bluetooth。
- [佳博 GP-M325F/GP-M325 操作说明](https://help.poscom.cn/blog-183.html)确认设备菜单包含“指令集”切换，并在 FAQ 中明确出现 **TSPL 模式**；同时提供标签学习和纸张类型设置。
- 公开官方资料没有确认 GP-M325F 的 macOS 专用驱动、蓝牙端口名称或固定纸张尺寸。因此这些内容必须在现场样机上确认，不能仅凭型号推断。

## 推荐架构

```text
Silverstack Backup + Verify
        |
        | final activity Post Step
        v
Lua onFinish(..., success)
        |
        | success=true: write manifest, os.execute()
        v
gp-m325f-bridge (Python/Shell)
        |
        | generate TSPL
        v
macOS CUPS raw queue OR Bluetooth serial bridge
        |
        v
GP-M325F label
```

### 方案 A：CUPS raw 队列，优先推荐

1. 在 macOS 中先用厂商驱动或 Generic/Raw 建立名为 `GP-M325F` 的打印队列。
2. 让 helper 生成 `label.tspl`，使用 `lp -d GP-M325F -o raw label.tspl` 发送原始 TSPL。
3. CUPS 负责队列、暂停、重试和系统级打印状态；Lua 不直接操作 USB/Bluetooth 设备。

该方案的前提是设备驱动/队列能够接受 raw job。若厂商驱动会改写 TSPL，则改用“Generic/Raw”队列，或使用官方驱动生成 PDF/图像标签。

### 方案 B：蓝牙串口桥接

1. 按佳博官方蓝牙配对说明完成配对，并确认 macOS 是否出现 `/dev/cu.*` 串口设备。
2. helper 通过串口写入 TSPL，设置合理的波特率、超时和独占锁。
3. 若蓝牙只暴露为应用私有协议而没有串口设备，则不能用 `cat` 或 Python serial 直接打印，需要佳博 SDK/专用 App 或回到 CUPS/USB 方案。

方案 B 的现场稳定性通常低于 CUPS，适合便携使用但必须做断电、离线、重复提交和蓝牙重连测试。

## Silverstack Lua 示例

下面的示例故意只写 manifest，不把素材路径直接拼进 TSPL，也不在 Lua 中实现打印协议。实际字段名以 Silverstack 版本内置 API reference 为准。

```lua
-- sst: post-step

local function shellQuote(value)
    local text = tostring(value or "")
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

function onFinish(assets, resources, workingPath, success)
    if not success then
        print("GP-M325F: Silverstack activity failed; skip label")
        return "skipped: workflow failed"
    end

    local manifestPath = workingPath .. "/.gp-m325f-label-manifest.txt"
    local file = assert(io.open(manifestPath, "w"))
    file:write("status=verified\\n")
    file:write("asset_count=" .. tostring(#assets) .. "\\n")
    file:write("resource_count=" .. tostring(#resources) .. "\\n")

    if assets[1] then
        local metadata = assets[1]:metadata()
        if metadata then
            file:write("camera_index=" .. tostring(metadata:getCameraIndex() or "") .. "\\n")
            file:write("dit=" .. tostring(metadata:getDIT() or "") .. "\\n")
        end
    end

    if resources[1] then
        file:write("resource_path=" .. tostring(resources[1]:getPath() or "") .. "\\n")
    end
    file:close()

    local command = "/usr/local/bin/gp-m325f-bridge --manifest " .. shellQuote(manifestPath)
    local exitCode = os.execute(command)
    if exitCode ~= true and exitCode ~= 0 then
        error("GP-M325F bridge failed")
    end
    return "printed: " .. manifestPath
end
```

## Helper 行为建议

helper 至少应完成以下步骤：

1. 读取 manifest，校验 `status=verified`。
2. 从 Silverstack 资源路径提取 source volume、项目名、拍摄日、卡号和目标盘信息；不要通过扫描目的地猜测源卡。
3. 生成固定宽度 TSPL，例如按实际标签校准 `SIZE`、`GAP`、`DIRECTION`、`TEXT`、`QRCODE`、`PRINT`。
4. 标签内容建议包含：项目名、拍摄日、机位/卡号、素材数量、主盘/克隆盘状态、Silverstack job 标识、打印时间、报告或 MHL 路径摘要。
5. 先把 TSPL 保存到 job 日志目录，再提交打印；记录打印队列返回值和 manifest 哈希。
6. 失败时不要让 Silverstack 的拷贝状态变成失败以外的“伪成功”；建议写入 `.failed` 记录，并由 DIT 手工重印。

中文不应直接假定由 GP-M325F 内置字体支持。第一版建议使用 ASCII/数字字段；需要中文时，把标签渲染为位图后使用 TSPL `BITMAP`，或走经过验证的 CUPS 图像/PDF 驱动。

## Workflow 放置位置

建议建立一个最终的 Backup activity，包含所有目的地和校验；把打印脚本放在该 activity 的最后一个 Post Step。不要把脚本放在单独的 transcode 或 report activity 上，否则可能在素材拷贝尚未完成时打印“已完成”标签，或同一张卡因多个子活动重复打印。

初期可先把 Lua 中的 `os.execute()` 替换为只写 manifest 和日志，确认 Silverstack 的 `success`、资源路径和字段值正确，再打开真实打印。

## 风险与验收

- 版本/授权：先确认现场是 Silverstack XT 还是 Lab，以及版本是否至少为 9.2.0；旧版本可能没有该 scripting feature。
- 打印机指令集：在 GP-M325F 自检页确认当前为 TSPL，而不是票据模式或其他指令集。
- 纸张校准：用实际标签尺寸设置 `SIZE`/`GAP`，先打印 20 张连续标签验证偏移、断纸和重启行为。
- 触发语义：用故意失败的校验任务确认 `success=false` 不打印；用双目的地任务确认两份都验证通过后才打印。
- 幂等性：Silverstack 重试 post-step 时不能无条件重复打印；应使用 job/source 唯一键写入本地 ledger，提供明确的 `--reprint` 人工命令。
- 安全：不要在 Lua 中使用未固定路径的 shell 参数；不要让标签打印脚本执行格式化、删除或覆盖素材操作。

