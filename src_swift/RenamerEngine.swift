import Foundation

public final class RenamerEngine {
    public static func renameVolumeAsync(
        at path: String,
        bsdNode: String,
        volumeUUID: String?,
        mediaUUID: String?,
        fileSystem: String = "",
        to requestedName: String
    ) async -> (success: Bool, message: String, actualName: String?) {
        await withCheckedContinuation { continuation in
            renameVolume(
                at: path,
                bsdNode: bsdNode,
                volumeUUID: volumeUUID,
                mediaUUID: mediaUUID,
                fileSystem: fileSystem,
                to: requestedName
            ) { success, message, actualName in
                continuation.resume(returning: (success, message, actualName))
            }
        }
    }

    public static func renameVolume(
        at path: String,
        bsdNode: String,
        volumeUUID: String?,
        mediaUUID: String?,
        fileSystem: String = "",
        to requestedName: String,
        completion: @escaping (Bool, String, String?) -> Void
    ) {
        let normalizedName = requestedName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let allowed = try? NSRegularExpression(pattern: "^[A-Z0-9_-]+$")
        let nameRange = NSRange(location: 0, length: normalizedName.utf16.count)
        guard !normalizedName.isEmpty,
              allowed?.firstMatch(in: normalizedName, options: [], range: nameRange) != nil else {
            complete(completion, success: false, message: "无效的新卷名：仅允许大写字母、数字、下划线和连字符。")
            return
        }

        let fsLower = fileSystem.lowercased()
        let isFatOrExFat = fsLower.contains("fat") || fsLower.contains("ms-dos") || fsLower.contains("exfat")
        guard !isFatOrExFat || normalizedName.count <= 11 else {
            complete(completion, success: false, message: "重命名失败：\(fileSystem.isEmpty ? "FAT/exFAT" : fileSystem) 卷名最多 11 个字符，未执行截断或改写。")
            return
        }

        guard bsdNode.range(of: #"^disk[0-9]+s[0-9]+$"#, options: .regularExpression) != nil else {
            complete(completion, success: false, message: "重命名失败：未确认有效的卷分区 BSD 节点。")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let before = diskInfo(for: path),
                  before.deviceIdentifier == bsdNode,
                  before.mountPoint == path,
                  let expectedVolumeUUID = volumeUUID,
                  before.volumeUUID == expectedVolumeUUID,
                  mediaUUID == nil || before.mediaUUID == mediaUUID else {
                complete(completion, success: false, message: "重命名已取消：目标卷的挂载路径、BSD 节点或 UUID 已变化，可能已拔卡或被复用。")
                return
            }

            do {
                let rename = try runDiskUtil(arguments: ["rename", bsdNode, normalizedName])
                guard rename.status == 0 else {
                    let detail = rename.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    complete(completion, success: false, message: "重命名失败：\(detail.isEmpty ? "diskutil 未提供错误信息。" : detail)")
                    return
                }

                guard let after = diskInfo(for: bsdNode),
                      after.deviceIdentifier == bsdNode,
                      after.volumeUUID == expectedVolumeUUID,
                      mediaUUID == nil || after.mediaUUID == mediaUUID,
                      after.volumeName == normalizedName else {
                    complete(
                        completion,
                        success: false,
                        message: "重命名已执行，但未通过同一 BSD 节点和 UUID 复核，请人工检查卷名后再继续。",
                        actualName: normalizedName
                    )
                    return
                }

                let unmount = try runDiskUtil(arguments: ["unmount", "force", bsdNode])
                guard unmount.status == 0 else {
                    let detail = unmount.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    complete(
                        completion,
                        success: false,
                        message: "卷已重命名为 \(after.volumeName ?? normalizedName)，但强制卸载失败：\(detail.isEmpty ? "diskutil 未提供错误信息。" : detail)",
                        actualName: after.volumeName
                    )
                    return
                }

                let mount = try runDiskUtil(arguments: ["mount", bsdNode])
                guard mount.status == 0 else {
                    let detail = mount.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    complete(
                        completion,
                        success: false,
                        message: "卷已重命名并卸载，但自动重挂载失败：\(detail.isEmpty ? "diskutil 未提供错误信息。" : detail)",
                        actualName: after.volumeName
                    )
                    return
                }

                guard let remounted = waitForRemountedDisk(
                    bsdNode: bsdNode,
                    expectedVolumeUUID: expectedVolumeUUID,
                    expectedMediaUUID: mediaUUID,
                    expectedName: normalizedName
                ),
                      remounted.deviceIdentifier == bsdNode,
                      remounted.volumeUUID == expectedVolumeUUID,
                      mediaUUID == nil || remounted.mediaUUID == mediaUUID,
                      remounted.volumeName == normalizedName,
                      remounted.mountPoint != nil else {
                    complete(
                        completion,
                        success: false,
                        message: "卷已重命名并执行重挂载，但最终 UUID、卷名或挂载点复核失败，请人工检查。",
                        actualName: after.volumeName
                    )
                    return
                }

                complete(
                    completion,
                    success: true,
                    message: "重命名成功：\(remounted.volumeName ?? normalizedName)。已强制卸载并重挂载同一 BSD 节点，系统句柄已刷新。",
                    actualName: remounted.volumeName
                )
            } catch {
                complete(completion, success: false, message: "系统执行错误：\(error.localizedDescription)")
            }
        }
    }

    private struct DiskInfo {
        let deviceIdentifier: String
        let volumeUUID: String?
        let mediaUUID: String?
        let mountPoint: String?
        let volumeName: String?
    }

    private struct DiskUtilResult {
        let status: Int32
        let standardOutput: String
        let standardError: String

        var combinedOutput: String {
            [standardOutput, standardError]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    private enum DiskUtilError: LocalizedError {
        case timedOut([String])

        var errorDescription: String? {
            switch self {
            case .timedOut(let arguments):
                return "diskutil \(arguments.joined(separator: " ")) 超过 20 秒未完成。"
            }
        }
    }

    private static func runDiskUtil(arguments: [String], timeout: TimeInterval = 20) throws -> DiskUtilResult {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        let completion = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        process.terminationHandler = { _ in completion.signal() }
        try process.run()

        guard completion.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            _ = completion.wait(timeout: .now() + 1)
            throw DiskUtilError.timedOut(arguments)
        }

        return DiskUtilResult(
            status: process.terminationStatus,
            standardOutput: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            standardError: String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }

    private static func diskInfo(for target: String) -> DiskInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", target]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let plist = try? PropertyListSerialization.propertyList(
                  from: output.fileHandleForReading.readDataToEndOfFile(), options: [], format: nil
              ) as? [String: Any],
              let deviceIdentifier = plist["DeviceIdentifier"] as? String else { return nil }

        return DiskInfo(
            deviceIdentifier: deviceIdentifier,
            volumeUUID: plist["VolumeUUID"] as? String,
            mediaUUID: plist["MediaUUID"] as? String,
            mountPoint: plist["MountPoint"] as? String,
            volumeName: plist["VolumeName"] as? String
        )
    }

    private static func waitForRemountedDisk(
        bsdNode: String,
        expectedVolumeUUID: String,
        expectedMediaUUID: String?,
        expectedName: String,
        timeout: TimeInterval = 5
    ) -> DiskInfo? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let info = diskInfo(for: bsdNode),
               info.deviceIdentifier == bsdNode,
               info.volumeUUID == expectedVolumeUUID,
               expectedMediaUUID == nil || info.mediaUUID == expectedMediaUUID,
               info.volumeName == expectedName,
               info.mountPoint != nil {
                return info
            }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return nil
    }

    private static func complete(
        _ completion: @escaping (Bool, String, String?) -> Void,
        success: Bool,
        message: String,
        actualName: String? = nil
    ) {
        DispatchQueue.main.async {
            completion(success, message, actualName)
        }
    }
}
