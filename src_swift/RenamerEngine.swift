import Foundation

public class RenamerEngine {
    public static func renameVolume(at path: String, bsdNode: String, fileSystem: String = "", to newName: String, completion: @escaping (Bool, String) -> Void) {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        var cleanName = newName.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined().uppercased()
        
        guard !cleanName.isEmpty else {
            completion(false, "无效的新卷名")
            return
        }
        
        let fsLower = fileSystem.lowercased()
        let isFatOrExFat = fsLower.contains("fat") || fsLower.contains("ms-dos") || fsLower.contains("udf") || fsLower.contains("exfat") || fsLower.isEmpty
        
        var wasOptimized = false
        let originalRequestedName = cleanName
        
        if isFatOrExFat && cleanName.count > 11 {
            wasOptimized = true
            // If cleanName is like A001_260803UJ (13 chars), optimize it:
            // If it matches pattern Camera_YYMMDDSuffix (e.g. A001_260803UJ), we can remove "26" (century) -> A001_0803UJ (11 chars)
            let regex = try? NSRegularExpression(pattern: "^([A-Z0-9]+)_\\d{2}(\\d{4})([A-Z0-9]*)$")
            let nsRange = NSRange(location: 0, length: cleanName.utf16.count)
            if let match = regex?.firstMatch(in: cleanName, options: [], range: nsRange) {
                let prefix = String(cleanName[Range(match.range(at: 1), in: cleanName)!])
                let mmdd = String(cleanName[Range(match.range(at: 2), in: cleanName)!])
                let suffix = String(cleanName[Range(match.range(at: 3), in: cleanName)!])
                let candidate = "\(prefix)_\(mmdd)\(suffix)"
                if candidate.count <= 11 {
                    cleanName = candidate
                } else {
                    cleanName = String(cleanName.prefix(11))
                }
            } else {
                cleanName = String(cleanName.prefix(11))
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Target specific partition BSD Node (e.g., disk3s1) or path, NEVER parent physical disk (disk3)
            let targetDevice = bsdNode.hasPrefix("disk") ? bsdNode : path
            
            // Step 1: diskutil rename requires the volume to be MOUNTED.
            let renameProcess = Process()
            renameProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            renameProcess.arguments = ["rename", targetDevice, cleanName]
            
            let pipe = Pipe()
            renameProcess.standardOutput = pipe
            renameProcess.standardError = pipe
            
            do {
                try renameProcess.run()
                renameProcess.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if renameProcess.terminationStatus == 0 {
                    // Step 2: Safe Remount (Unmount new path & Remount BSD node) to flush Silverstack / Finder handles
                    let newPath = "/Volumes/\(cleanName)"
                    let unmountProcess = Process()
                    unmountProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                    unmountProcess.arguments = ["unmount", newPath]
                    try? unmountProcess.run()
                    unmountProcess.waitUntilExit()
                    
                    let mountProcess = Process()
                    mountProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                    mountProcess.arguments = ["mount", targetDevice]
                    try? mountProcess.run()
                    mountProcess.waitUntilExit()
                    
                    DispatchQueue.main.async {
                        if wasOptimized {
                            completion(true, "重命名成功！检测到 \(fileSystem.isEmpty ? "exFAT/FAT32" : fileSystem) 文件系统限定卷名上限为 11 位，已智能优化 \(originalRequestedName) ➔ \(cleanName) 并完成重命名。")
                        } else {
                            completion(true, "重命名成功！已更名为 \(cleanName) 且完成系统级深度挂载刷新")
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        let errStr = output.trimmingCharacters(in: .whitespacesAndNewlines)
                        if errStr.contains("does not appear to be a valid volume name") {
                            completion(false, "重命名失败: 目标文件系统 (\(fileSystem.isEmpty ? "exFAT/FAT32" : fileSystem)) 不支持超过 11 位的卷名 (\(originalRequestedName) 达 \(originalRequestedName.count) 位)。已为您开启智能防超限保护。")
                        } else {
                            completion(false, "重命名失败: \(errStr)")
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "系统执行错误: \(error.localizedDescription)")
                }
            }
        }
    }
}
