import Foundation
import Combine
import SwiftUI

/// 负责重命名历史记录的独立持久化存储管理器
/// 存储于 `~/Library/Application Support/DITRenamer/rename_history.json`
/// 并追加保存于 `~/Library/Logs/DIT_Renamer/rename_history.log`
public class RenameHistoryStore: ObservableObject {
    public static let shared = RenameHistoryStore()
    
    @Published public private(set) var items: [RenameHistoryItem] = []
    
    private let fileManager = FileManager.default
    private let appSupportDir: URL
    private let jsonFileURL: URL
    private let logFileURL: URL
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportDir = appSupport.appendingPathComponent("DITRenamer")
        jsonFileURL = appSupportDir.appendingPathComponent("rename_history.json")
        
        let logsDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DIT_Renamer")
        logFileURL = logsDir.appendingPathComponent("rename_history.log")
        
        // 自动创建文件夹目录
        try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        loadHistory()
    }
    
    /// 加载历史记录（兼顾 UserDefaults 迁移）
    public func loadHistory() {
        if fileManager.fileExists(atPath: jsonFileURL.path),
           let data = try? Data(contentsOf: jsonFileURL),
           let loaded = try? JSONDecoder().decode([RenameHistoryItem].self, from: data) {
            self.items = loaded
        } else {
            // 从 UserDefaults 恢复历史并迁移写入本地文件
            if let legacyData = UserDefaults.standard.data(forKey: "renameHistoryData"),
               let legacyItems = try? JSONDecoder().decode([RenameHistoryItem].self, from: legacyData) {
                self.items = legacyItems
                saveHistory()
            }
        }
    }
    
    /// 添加一条新的重命名记录
    public func add(_ item: RenameHistoryItem) {
        items.insert(item, at: 0)
        saveHistory()
        appendLogText(item: item)
    }
    
    /// 判断某张卡/某个卷名是否已经在本软件中成功重命名过
    public func isRenamed(volumeName: String, firstClipName: String? = nil) -> Bool {
        return items.contains { record in
            if record.newName == volumeName { return true }
            if let first = firstClipName, let recFirst = record.firstClipName, !first.isEmpty, first == recFirst {
                return record.newName == volumeName
            }
            return false
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: jsonFileURL, options: .atomic)
            // 同步写回 UserDefaults 备用
            UserDefaults.standard.set(data, forKey: "renameHistoryData")
        }
    }
    
    private func appendLogText(item: RenameHistoryItem) {
        let line = "[\(item.dateDayString) \(item.formattedTime)] RENAMED '\(item.originalName)' -> '\(item.newName)' | Clips: \(item.clipCount), Files: \(item.totalFileCount), Space: \(item.usedSpace), Device: \(item.deviceType)\n"
        if let data = line.data(using: .utf8) {
            if fileManager.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFileURL, options: .atomic)
            }
        }
    }
}
