import Foundation
import Combine

public struct ParaShootEraseEvent: Identifiable {
    public let id = UUID()
    public let timestamp: String // e.g. "13:12:34"
    public let date: String // e.g. "2025-10-24"
    public let volumeName: String
    public let deviceVendor: String
    public let deviceModel: String
    public let bsdUnit: String // e.g. "5" -> "disk5"
    public let missingFilesCount: Int
    public let isSafe: Bool
    
    /// 格式化为 YY/MM/DD  HH:MM:SS，用于 UI 卡片和 PDF 报告
    public var formattedDateTime: String {
        let parts = date.components(separatedBy: "-") // ["2025","10","24"]
        guard parts.count == 3 else { return "\(date) \(timestamp)" }
        let yy = String(parts[0].suffix(2))
        return "\(yy)/\(parts[1])/\(parts[2])  \(timestamp)"
    }
}

public struct ParaShootDailyReport {
    public let date: String
    public let events: [ParaShootEraseEvent]
}

public class ParaShootParser: ObservableObject {
    public static let shared = ParaShootParser()
    
    @Published public var reports: [ParaShootDailyReport] = []
    
    private let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/ParaShoot/parashoot.log")
    
    private var fileSource: DispatchSourceFileSystemObject?
    private var directorySource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var directoryDescriptor: Int32 = -1
    private var pollTimer: Timer?
    
    public init() {
        reloadLogs()
        startWatching()
    }
    
    deinit {
        stopWatching()
    }
    
    public func reloadLogs() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let parsed = self.parseLogs()
            DispatchQueue.main.async {
                self.reports = parsed
            }
        }
    }
    
    private func startWatching() {
        let logDir = logPath.deletingLastPathComponent()
        
        // 1. Watch Directory for file creation/replacement
        directoryDescriptor = open(logDir.path, O_EVTONLY)
        if directoryDescriptor >= 0 {
            let dirSource = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: directoryDescriptor,
                eventMask: [.write, .extend, .attrib, .link, .rename, .delete],
                queue: DispatchQueue.global(qos: .default)
            )
            dirSource.setEventHandler { [weak self] in
                self?.reloadLogs()
                self?.rebindFileWatcher()
            }
            dirSource.resume()
            self.directorySource = dirSource
        }
        
        rebindFileWatcher()
        
        // 2. Real-time polling fallback (2.0s) to guarantee zero-latency updates
        DispatchQueue.main.async {
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.reloadLogs()
            }
        }
    }
    
    private func rebindFileWatcher() {
        if fileDescriptor >= 0 {
            fileSource?.cancel()
            close(fileDescriptor)
            fileDescriptor = -1
        }
        
        let path = logPath.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib],
            queue: DispatchQueue.global(qos: .default)
        )
        source.setEventHandler { [weak self] in
            self?.reloadLogs()
        }
        source.resume()
        self.fileSource = source
    }
    
    private func stopWatching() {
        pollTimer?.invalidate()
        pollTimer = nil
        
        if fileDescriptor >= 0 {
            fileSource?.cancel()
            close(fileDescriptor)
            fileDescriptor = -1
        }
        if directoryDescriptor >= 0 {
            directorySource?.cancel()
            close(directoryDescriptor)
            directoryDescriptor = -1
        }
    }
    
    public func parseLogs() -> [ParaShootDailyReport] {
        guard let content = try? String(contentsOf: logPath, encoding: .utf8) else {
            return []
        }
        
        let lines = content.components(separatedBy: .newlines)
        var events: [ParaShootEraseEvent] = []
        var lastMissingCount = 0
        
        for line in lines {
            if line.contains("CheckResult{missing: {") {
                lastMissingCount = line.components(separatedBy: "FileSignature(").count - 1
            }
            
            if line.contains("Erasing DiskInfo(") {
                let parts = line.components(separatedBy: " | ")
                if parts.count >= 3 {
                    let timePart = parts[0]
                    let msgPart = parts[2]
                    
                    let timeTokens = timePart.components(separatedBy: " ")
                    guard timeTokens.count == 2 else { continue }
                    let dateStr = timeTokens[0]
                    let timeStr = String(timeTokens[1].prefix(8))
                    
                    let name = extractValue(from: msgPart, key: "name: ")
                    let vendor = extractValue(from: msgPart, key: "deviceVendor: ")
                    let model = extractValue(from: msgPart, key: "deviceModel: ")
                    let bsd = extractValue(from: msgPart, key: "mediaBSDUnit: ")
                    
                    let event = ParaShootEraseEvent(
                        timestamp: timeStr,
                        date: dateStr,
                        volumeName: name.isEmpty ? "Unknown" : name,
                        deviceVendor: vendor.isEmpty ? "Unknown" : vendor,
                        deviceModel: model.isEmpty ? "Unknown" : model,
                        bsdUnit: bsd.isEmpty ? "-" : "disk\(bsd)",
                        missingFilesCount: max(0, lastMissingCount),
                        isSafe: lastMissingCount <= 0
                    )
                    events.append(event)
                    
                    lastMissingCount = 0
                }
            }
        }
        
        let grouped = Dictionary(grouping: events, by: { $0.date })
        return grouped.map { ParaShootDailyReport(date: $0.key, events: $0.value.sorted(by: { $0.timestamp > $1.timestamp })) }
            .sorted(by: { $0.date > $1.date })
    }
    
    private func extractValue(from text: String, key: String) -> String {
        guard let range = text.range(of: key) else { return "" }
        let sub = text[range.upperBound...]
        if let commaRange = sub.range(of: ", ") {
            return String(sub[..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else if let parenRange = sub.range(of: ")") {
            return String(sub[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}
