import SwiftUI

struct ParaShootAuditView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var langManager = LanguageManager.shared
    
    @ObservedObject var parashootParser = ParaShootParser.shared
    @State private var selectedExportDays: Set<String> = []
    
    var parashootReports: [ParaShootDailyReport] {
        parashootParser.reports
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(langManager.text("ParaShoot 擦卡审计报告", "ParaShoot Erase Audit"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(langManager.text("按日期查看及批量导出安全的格式化日志 (PDF)", "View & Batch Export Erase Audit Logs (PDF)"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            if parashootReports.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(langManager.text("未发现任何 ParaShoot 日志记录。", "No ParaShoot logs found."))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(minHeight: 200)
            } else {
                List(parashootReports, id: \.date) { report in
                    HStack(spacing: 12) {
                        Image(systemName: selectedExportDays.contains(report.date) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(selectedExportDays.contains(report.date) ? .blue : .secondary)
                            .onTapGesture {
                                if selectedExportDays.contains(report.date) {
                                    selectedExportDays.remove(report.date)
                                } else {
                                    selectedExportDays.insert(report.date)
                                }
                            }
                        
                        VStack(alignment: .leading) {
                            Text(report.date)
                                .font(.headline)
                            Text("\(report.events.count) \(langManager.text("次擦除记录", "media wiped"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            exportParaShootPDF(for: report)
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("PDF")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset)
                .frame(minHeight: 250)
                
                // Bottom multi-day export toolbar
                if !selectedExportDays.isEmpty {
                    Divider()
                    HStack {
                        Text("\(langManager.text("已选", "Selected")) \(selectedExportDays.count) \(langManager.text("天记录", "days"))")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Button(action: exportMultipleParaShootDays) {
                            Label(langManager.text("批量导出 PDF 报告", "Export Batch PDF"), systemImage: "square.and.arrow.up")
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
        .frame(width: 480, height: 420)
        .onAppear {
            parashootParser.reloadLogs()
        }
    }
    
    private func exportMultipleParaShootDays() {
        let sortedDays = selectedExportDays.sorted(by: >)
        let dict = Dictionary(uniqueKeysWithValues: parashootReports.map { ($0.date, $0) })
        let selectedReports = sortedDays.compactMap { dict[$0] }
        let mergedEvents = selectedReports.flatMap { $0.events }
        let dateLabel = sortedDays.prefix(3).joined(separator: "_") + (sortedDays.count > 3 ? "_etc" : "")
        let mergedReport = ParaShootDailyReport(date: dateLabel, events: mergedEvents)
        
        exportParaShootPDF(for: mergedReport)
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
                        DispatchQueue.main.async {
                            try? data.write(to: url)
                        }
                    }
                }
            }
        }
    }
}
