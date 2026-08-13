import Foundation

public enum RenameAuditFormatting {
    public static func includesReuseCount(_ items: [RenameHistoryItem]) -> Bool {
        items.contains { $0.reuseCount != nil }
    }

    public static func pdfReuseHeaderHTML(items: [RenameHistoryItem], isChinese: Bool) -> String {
        guard includesReuseCount(items) else { return "" }
        let title = isChinese ? "卡片复用次数" : "Card Reuse Count"
        return "<th style=\"text-align:center;\">\(title)</th>"
    }

    public static func pdfReuseCellHTML(item: RenameHistoryItem, includeColumn: Bool) -> String {
        guard includeColumn else { return "" }
        return "<td style=\"text-align:center;\">\(item.reuseCount.map(String.init) ?? "")</td>"
    }

    public static func csvDocument(items: [RenameHistoryItem]) -> String {
        let includeReuseCount = includesReuseCount(items)
        var headers = ["Original Name", "New Name"]
        if includeReuseCount { headers.append("Card Reuse Count") }
        headers += ["First Clip", "Last Clip", "Clip Count", "Total Files", "Used Space", "Device Type", "Time"]
        var csv = "\u{FEFF}" + headers.joined(separator: ",") + "\n"
        for item in items {
            var fields = [item.originalName, item.newName]
            if includeReuseCount { fields.append(item.reuseCount.map(String.init) ?? "") }
            fields += [
                item.firstClipName ?? "-",
                item.lastClipName ?? "-",
                String(item.clipCount),
                String(item.totalFileCount),
                item.usedSpace,
                item.deviceType,
                item.formattedTime
            ]
            csv += fields.map(csvField).joined(separator: ",") + "\n"
        }
        return csv
    }

    private static func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
