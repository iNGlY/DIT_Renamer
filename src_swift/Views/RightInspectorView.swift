import SwiftUI
import UniformTypeIdentifiers

enum AuditTab: Int, CaseIterable, Identifiable {
    case rename = 0
    case parashoot = 1
    
    var id: Int { rawValue }
}

class ClosureMenuItem: NSMenuItem {
    private var closure: () -> Void
    
    init(title: String, closure: @escaping () -> Void) {
        self.closure = closure
        super.init(title: title, action: #selector(actionHandler), keyEquivalent: "")
        self.target = self
    }
    
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    @objc private func actionHandler() {
        closure()
    }
}

struct RightInspectorView: View {
    @ObservedObject var langManager = LanguageManager.shared
    @ObservedObject var historyStore = RenameHistoryStore.shared
    @Binding var selectedTab: AuditTab
    
    @ObservedObject var parashootParser = ParaShootParser.shared
    @State private var expandedGroupIds: Set<String> = []
    @State private var selectedExportDays: Set<String> = []
    @State private var exportError: ExportError?

    private enum ExportError: Identifiable {
        case message(String)

        var id: String {
            switch self {
            case .message(let text): return text
            }
        }

        var text: String {
            switch self {
            case .message(let text): return text
            }
        }
    }
    
    var parashootReports: [ParaShootDailyReport] {
        parashootParser.reports
    }
    
    init(selectedTab: Binding<AuditTab> = .constant(.rename)) {
        self._selectedTab = selectedTab
    }
    
    var historyItems: [RenameHistoryItem] {
        historyStore.items
    }
    
    var groupedRenameItems: [(day: String, items: [RenameHistoryItem])] {
        let dictionary = Dictionary(grouping: historyItems) { $0.dateDayString }
        return dictionary.keys.sorted(by: >).map { key in
            (day: key, items: dictionary[key]!)
        }
    }
    
    var parashootReportDict: [String: ParaShootDailyReport] {
        Dictionary(uniqueKeysWithValues: parashootReports.map { ($0.date, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text(langManager.text("历史操作审计", "Operation Audit History"))
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            
            // Segmented Picker
            Picker("", selection: $selectedTab) {
                Text(langManager.text("重命名历史", "Rename History")).tag(AuditTab.rename)
                Text(langManager.text("ParaShoot历史", "ParaShoot Log")).tag(AuditTab.parashoot)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            
            Divider()
            
            // Content according to selected tab
            if selectedTab == .rename {
                renameHistorySection
            } else {
                parashootHistorySection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear {
            historyStore.loadHistory()
            parashootParser.reloadLogs()
            if let firstDay = groupedRenameItems.first?.day {
                expandedGroupIds.insert(firstDay)
            }
            if let firstPS = parashootReports.first?.date {
                expandedGroupIds.insert(firstPS)
            }
        }
        .alert(item: $exportError) { error in
            Alert(
                title: Text(langManager.text("导出失败", "Export failed")),
                message: Text(error.text),
                dismissButton: .default(Text(langManager.text("确定", "OK")))
            )
        }
    }
    
    // MARK: - Rename History Tab View
    private var renameHistorySection: some View {
        VStack(spacing: 0) {
            if historyItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(langManager.text("暂无重命名历史记录", "No Rename History"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(groupedRenameItems, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                
                                // Day Disclosure Header
                                HStack(spacing: 6) {
                                    // Multi-select checkbox
                                    Image(systemName: selectedExportDays.contains(group.day) ? "checkmark.circle.fill" : "circle")
                                        .font(.caption)
                                        .foregroundColor(selectedExportDays.contains(group.day) ? .blue : .secondary)
                                        .onTapGesture {
                                            if selectedExportDays.contains(group.day) {
                                                selectedExportDays.remove(group.day)
                                            } else {
                                                selectedExportDays.insert(group.day)
                                            }
                                        }
                                    
                                    // Collapse toggle button
                                    Button(action: {
                                        if expandedGroupIds.contains(group.day) {
                                            expandedGroupIds.remove(group.day)
                                        } else {
                                            expandedGroupIds.insert(group.day)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: expandedGroupIds.contains(group.day) ? "chevron.down" : "chevron.right")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(group.day)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                            Spacer()
                                            Text("\(group.items.count) \(langManager.text("次记录", "logs"))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Export Menu button (No extra chevron arrow)
                                    Button(action: {
                                        showRenameExportMenu(groupDay: group.day, items: group.items)
                                    }) {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 22)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(selectedExportDays.contains(group.day) ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
                                .cornerRadius(6)
                                
                                // Items in Day Group (Collapsible, respects user toggling)
                                if expandedGroupIds.contains(group.day) {
                                    ForEach(group.items) { item in
                                        historyCard(item: item)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                
                // Bottom multi-day export toolbar
                if !selectedExportDays.isEmpty {
                    Divider()
                    HStack {
                        Text("\(langManager.text("已选", "Selected")) \(selectedExportDays.count) \(langManager.text("天", "days"))")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Button(action: exportMultipleDays) {
                            Label(langManager.text("批量导出 PDF", "Export PDF"), systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button(action: { selectedExportDays.removeAll() }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
    }
    
    // MARK: - ParaShoot History Tab View
    private var parashootHistorySection: some View {
        VStack(spacing: 0) {
            if parashootReports.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(langManager.text("未发现 ParaShoot 擦除日志", "No ParaShoot logs found"))
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(parashootReports, id: \.date) { report in
                            VStack(alignment: .leading, spacing: 6) {
                                // Day Header — separate collapse arrow, date text, count, and export button
                                HStack(spacing: 6) {
                                    // Multi-select checkbox
                                    Image(systemName: selectedExportDays.contains(report.date) ? "checkmark.circle.fill" : "circle")
                                        .font(.caption)
                                        .foregroundColor(selectedExportDays.contains(report.date) ? .blue : .secondary)
                                        .onTapGesture {
                                            if selectedExportDays.contains(report.date) {
                                                selectedExportDays.remove(report.date)
                                            } else {
                                                selectedExportDays.insert(report.date)
                                            }
                                        }
                                    
                                    // Collapse arrow
                                    Button(action: {
                                        if expandedGroupIds.contains(report.date) {
                                            expandedGroupIds.remove(report.date)
                                        } else {
                                            expandedGroupIds.insert(report.date)
                                        }
                                    }) {
                                        Image(systemName: expandedGroupIds.contains(report.date) ? "chevron.down" : "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Date label — tappable to toggle collapse
                                    Button(action: {
                                        if expandedGroupIds.contains(report.date) {
                                            expandedGroupIds.remove(report.date)
                                        } else {
                                            expandedGroupIds.insert(report.date)
                                        }
                                    }) {
                                        Text(report.date)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    Text("\(report.events.count) \(langManager.text("擦除", "wiped"))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    // Export Share Button (Clean Button, NO extra chevron arrow!)
                                    Button(action: {
                                        showParaShootExportMenu(report: report)
                                    }) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 22)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(selectedExportDays.contains(report.date) ? Color.blue.opacity(0.12) : Color.green.opacity(0.12))
                                .cornerRadius(6)
                                
                                // Events List (Collapsible, respects user toggling)
                                if expandedGroupIds.contains(report.date) {
                                    ForEach(report.events) { event in
                                        parashootEventCard(event: event)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                
                // Bottom multi-day export toolbar
                if !selectedExportDays.isEmpty {
                    Divider()
                    HStack {
                        Text("\(langManager.text("已选", "Selected")) \(selectedExportDays.count) \(langManager.text("天", "days"))")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Button(action: exportMultipleParaShootDays) {
                            Label(langManager.text("批量导出 PDF", "Export PDF"), systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        Button(action: { selectedExportDays.removeAll() }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
    }
    
    // MARK: - Cards & Export Actions
    private func historyCard(item: RenameHistoryItem) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.originalName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
                Text(item.newName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                if item.isUnformatted == true || item.deviceType.contains("Unformatted") {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text(langManager.text("未格式化", "Unformatted"))
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(4)
                } else if item.isEmptyCard == true || item.clipCount == 0 || item.deviceType.contains("Empty") {
                    HStack(spacing: 2) {
                        Image(systemName: "tray")
                            .font(.system(size: 8))
                        Text(langManager.text("空卡", "Empty"))
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.gray)
                    .cornerRadius(4)
                } else if item.deviceType.contains("Photo") {
                    HStack(spacing: 2) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 8))
                        Text(langManager.text("照片卡", "Photo"))
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
                }
                
                Spacer()
                Text(item.formattedTime)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Text("\(langManager.text("首卡", "First")): \(item.firstClipName ?? "-")")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text("\(langManager.text("尾卡", "Last")): \(item.lastClipName ?? "-")")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack {
                Text("\(langManager.text("素材数", "Clips")): \(item.clipCount)  ·  \(langManager.text("文件总数", "Files")): \(item.totalFileCount)  ·  \(item.usedSpace)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text(item.deviceType)
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }
    
    private func parashootEventCard(event: ParaShootEraseEvent) -> some View {
        let statusText: String
        let statusColor: Color
        if !event.isVerificationKnown {
            statusText = langManager.text("未知", "Unknown")
            statusColor = .orange
        } else if event.isSafe {
            statusText = langManager.text("校验通过", "Verified")
            statusColor = .green
        } else {
            statusText = langManager.text("缺失警示", "Missing Warning")
            statusColor = .red
        }

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.volumeName)
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                Text(event.formattedDateTime)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(event.deviceVendor) \(event.deviceModel)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text(statusText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(statusColor)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.15))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(statusColor.opacity(0.3), lineWidth: 1))
    }
    
    private func showRenameExportMenu(groupDay: String, items: [RenameHistoryItem]) {
        let menu = NSMenu()
        let item1 = ClosureMenuItem(title: langManager.text("导出重命名历史 (CSV)", "Export Rename CSV")) {
            exportCSV(for: items, dateStr: groupDay)
        }
        menu.addItem(item1)
        
        if let psReport = parashootReportDict[groupDay] {
            let item2 = ClosureMenuItem(title: langManager.text("导出联合 DIT 报告 (PDF)", "Export Combined DIT Report (PDF)")) {
                exportCombinedPDF(dateStr: groupDay, renameItems: items, parashootReport: psReport)
            }
            menu.addItem(item2)
        } else {
            let item3 = ClosureMenuItem(title: langManager.text("导出重命名报告 (PDF)", "Export Rename Report (PDF)")) {
                exportCombinedPDF(dateStr: groupDay, renameItems: items, parashootReport: nil)
            }
            menu.addItem(item3)
        }
        
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
    
    private func showParaShootExportMenu(report: ParaShootDailyReport) {
        let menu = NSMenu()
        let item1 = ClosureMenuItem(title: langManager.text("导出 ParaShoot 审计报告 (PDF)", "Export ParaShoot PDF")) {
            exportParaShootPDF(for: report)
        }
        menu.addItem(item1)
        
        if let renameGroup = groupedRenameItems.first(where: { $0.day == report.date }) {
            let item2 = ClosureMenuItem(title: langManager.text("导出联合 DIT 报告 (PDF)", "Export Combined DIT Report (PDF)")) {
                exportCombinedPDF(dateStr: report.date, renameItems: renameGroup.items, parashootReport: report)
            }
            menu.addItem(item2)
        }
        
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
    
    private func exportCSV(for items: [RenameHistoryItem], dateStr: String) {
        var csvString = "\u{FEFF}Original Name,New Name,First Clip,Last Clip,Clip Count,Total Files,Used Space,Device Type,Time\n"
        for item in items {
            let fields = [
                item.originalName,
                item.newName,
                item.firstClipName ?? "-",
                item.lastClipName ?? "-",
                String(item.clipCount),
                String(item.totalFileCount),
                item.usedSpace,
                item.deviceType,
                item.formattedTime
            ]
            csvString += fields.map(csvField).joined(separator: ",") + "\n"
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "DIT_Rename_Audit_\(dateStr).csv"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try csvString.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    exportError = .message(error.localizedDescription)
                }
            }
        }
    }

    private func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    private func exportMultipleDays() {
        let sortedDays = selectedExportDays.sorted(by: >)
        let allItems = sortedDays.flatMap { day in
            groupedRenameItems.first(where: { $0.day == day })?.items ?? []
        }
        let selectedReports = sortedDays.compactMap { parashootReportDict[$0] }
        let mergedEvents = selectedReports.flatMap(\.events)
        let label = sortedDays.prefix(3).joined(separator: "_") + (sortedDays.count > 3 ? "_etc" : "")
        let mergedPS = mergedEvents.isEmpty ? nil : ParaShootDailyReport(date: label, events: mergedEvents)
        exportCombinedPDF(dateStr: label, renameItems: allItems, parashootReport: mergedPS)
    }
    
    private func exportMultipleParaShootDays() {
        let sortedDays = selectedExportDays.sorted(by: >)
        let selectedReports = sortedDays.compactMap { parashootReportDict[$0] }
        let mergedEvents = selectedReports.flatMap { $0.events }
        let dateLabel = sortedDays.prefix(3).joined(separator: "_") + (sortedDays.count > 3 ? "_etc" : "")
        let mergedReport = ParaShootDailyReport(date: dateLabel, events: mergedEvents)
        
        let allRenameItems = sortedDays.flatMap { day in
            groupedRenameItems.first(where: { $0.day == day })?.items ?? []
        }
        
        exportCombinedPDF(dateStr: dateLabel, renameItems: allRenameItems, parashootReport: mergedReport)
    }
    
    private func exportParaShootPDF(for report: ParaShootDailyReport) {
        let lang = LanguageManager.shared.currentLanguage
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "ParaShoot_Audit_\(report.date).pdf"
        let associationOption = NSButton(
            checkboxWithTitle: lang == .zh ? "导出高置信度关联结果" : "Export high-confidence associations",
            target: nil,
            action: nil
        )
        associationOption.state = .off
        savePanel.accessoryView = associationOption
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                ParaShootPDFGenerator.shared.generatePDF(
                    for: report,
                    language: lang,
                    includeHighConfidenceAssociation: associationOption.state == .on
                ) { data in
                    if let data = data {
                        do { try data.write(to: url) }
                        catch { exportError = .message(error.localizedDescription) }
                    } else {
                        exportError = .message(langManager.text("PDF 生成失败。", "PDF generation failed."))
                    }
                }
            }
        }
    }
    
    private func exportCombinedPDF(dateStr: String, renameItems: [RenameHistoryItem], parashootReport: ParaShootDailyReport?) {
        let lang = LanguageManager.shared.currentLanguage
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "DIT_Unified_Audit_\(dateStr).pdf"
        let associationOption = NSButton(
            checkboxWithTitle: lang == .zh ? "导出高置信度关联结果" : "Export high-confidence associations",
            target: nil,
            action: nil
        )
        associationOption.state = .off
        savePanel.accessoryView = associationOption
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                ParaShootPDFGenerator.shared.generateCombinedPDF(
                    dateStr: dateStr,
                    renameItems: renameItems,
                    parashootReport: parashootReport,
                    language: lang,
                    includeHighConfidenceAssociation: associationOption.state == .on
                ) { data in
                    if let data = data {
                        do { try data.write(to: url) }
                        catch { exportError = .message(error.localizedDescription) }
                    } else {
                        exportError = .message(langManager.text("PDF 生成失败。", "PDF generation failed."))
                    }
                }
            }
        }
    }
}
