import Foundation
import WebKit

class ParaShootPDFGenerator: NSObject, WKNavigationDelegate {
    static let shared = ParaShootPDFGenerator()
    
    private var webViews: [ObjectIdentifier: WKWebView] = [:]
    private var completions: [ObjectIdentifier: (Data?) -> Void] = [:]
    
    func generatePDF(for report: ParaShootDailyReport,
                     language: AppLanguage,
                     includeHighConfidenceAssociation: Bool,
                     completion: @escaping (Data?) -> Void) {
        generateCombinedPDF(
            dateStr: report.date,
            renameItems: [],
            parashootReport: report,
            language: language,
            includeHighConfidenceAssociation: includeHighConfidenceAssociation,
            completion: completion
        )
    }
    
    func generateCombinedPDF(dateStr: String,
                             renameItems: [RenameHistoryItem],
                             parashootReport: ParaShootDailyReport?,
                             language: AppLanguage,
                             includeHighConfidenceAssociation: Bool,
                             completion: @escaping (Data?) -> Void) {
        let html = generateCombinedHTML(
            dateStr: dateStr,
            renameItems: renameItems,
            parashootReport: parashootReport,
            language: language,
            includeHighConfidenceAssociation: includeHighConfidenceAssociation
        )
        
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1131), configuration: config) // A4 ratio approx
        view.navigationDelegate = self
        let key = ObjectIdentifier(view)
        webViews[key] = view
        completions[key] = completion
        
        view.loadHTMLString(html, baseURL: nil)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let pdfConfig = WKPDFConfiguration()
        pdfConfig.rect = CGRect(x: 0, y: 0, width: 800, height: 1131)
        
        webView.createPDF(configuration: pdfConfig) { [weak self] result in
            guard let self else { return }
            let key = ObjectIdentifier(webView)
            switch result {
            case .success(let data):
                self.completions[key]?(data)
            case .failure(let error):
                print("PDF generation error: \(error)")
                self.completions[key]?(nil)
            }
            self.completions.removeValue(forKey: key)
            self.webViews.removeValue(forKey: key)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(webView: webView, data: nil, error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(webView: webView, data: nil, error: error)
    }

    private func finish(webView: WKWebView, data: Data?, error: Error?) {
        let key = ObjectIdentifier(webView)
        if let error { print("PDF generation error: \(error)") }
        completions[key]?(data)
        completions.removeValue(forKey: key)
        webViews.removeValue(forKey: key)
    }

    private func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func generateCombinedHTML(dateStr: String,
                                      renameItems: [RenameHistoryItem],
                                      parashootReport: ParaShootDailyReport?,
                                      language: AppLanguage,
                                      includeHighConfidenceAssociation: Bool) -> String {
        let isCN = (language == .zh)
        
        // MARK: - Localized strings
        let lDate       = isCN ? "日期" : "DATE"
        let lRenamed    = isCN ? "重命名卷数" : "RENAMED VOLUMES"
        let lWiped      = isCN ? "擦除记录" : "MEDIA WIPED"
        let lPrinted    = isCN ? "生成时间" : "PRINTED"
        let lTime       = isCN ? "操作时间" : "Time"
        let lOrigName   = isCN ? "原始卷名" : "Original Name"
        let lNewName    = isCN ? "新卷名" : "New Name"
        let lFirstClip  = isCN ? "首个素材" : "First Clip"
        let lLastClip   = isCN ? "末尾素材" : "Last Clip"
        let lClips      = isCN ? "素材数" : "Clips"
        let lFiles      = isCN ? "文件总数" : "Files"
        let lUsed       = isCN ? "已用空间" : "Used"
        let lDevType    = isCN ? "设备类型" : "Device Type"
        let lVolName    = isCN ? "卷名" : "Volume Name"
        let lDevInfo    = isCN ? "设备信息" : "Device Info"
        let lTarget     = isCN ? "挂载节点" : "Target"
        let lVerify     = isCN ? "验证状态" : "Verification Status"
        let lPassed     = isCN ? "校验通过" : "VERIFIED"
        let lAssociation = isCN ? "关联结果" : "Association"
        let lHighConfidence = isCN ? "高置信度：源路径匹配" : "HIGH CONFIDENCE: source path matched"
        let lAssociationUnavailable = isCN ? "未建立高置信度关联" : "No high-confidence association"
        let lBadge      = isCN ? "DIT 审计报告" : "DIT REPORT"
        let lFooter     = isCN ? "由 DIT Renamer 生成 © \(Calendar.current.component(.year, from: Date())) — 统一 DIT 审计报告" :
                                  "Generated by DIT Renamer © \(Calendar.current.component(.year, from: Date())) — Unified DIT Audit Integration"
        let lSec1Title  = isCN ? "1. 卡卷重命名记录" : "1. Media Volume Renaming Log"
        let lSec2Title  = isCN ? "2. ParaShoot 擦卡与安全验证日志" : "2. ParaShoot Erase & Verification Log"
        
        // MARK: - Section 1: Rename Log Rows
        let includesReuseCount = RenameAuditFormatting.includesReuseCount(renameItems)
        var renameRows = ""
        for item in renameItems {
            let first = htmlEscape(item.firstClipName ?? "-")
            let last = htmlEscape(item.lastClipName ?? "-")
            renameRows += """
            <tr>
                <td>\(htmlEscape(item.formattedTime))</td>
                <td><code style="background:#eef2ff; color:#3730a3;">\(htmlEscape(item.originalName))</code></td>
                <td><strong style="color:#059669;">\(htmlEscape(item.newName))</strong></td>
                \(RenameAuditFormatting.pdfReuseCellHTML(item: item, includeColumn: includesReuseCount))
                <td style="font-family:monospace; font-size:10px;">\(first)</td>
                <td style="font-family:monospace; font-size:10px;">\(last)</td>
                <td style="text-align:center;">\(item.clipCount)</td>
                <td style="text-align:center;">\(item.totalFileCount)</td>
                <td style="text-align:right;">\(item.usedSpace)</td>
                <td><span class="badge-blue">\(htmlEscape(item.deviceType))</span></td>
            </tr>
            """
        }
        
        var renameSection = ""
        if !renameItems.isEmpty {
            renameSection = """
            <div class="section-title">\(lSec1Title)</div>
            <table>
                <thead>
                    <tr>
                        <th>\(lTime)</th>
                        <th>\(lOrigName)</th>
                        <th>\(lNewName)</th>
                        \(RenameAuditFormatting.pdfReuseHeaderHTML(items: renameItems, isChinese: isCN))
                        <th>\(lFirstClip)</th>
                        <th>\(lLastClip)</th>
                        <th style="text-align:center;">\(lClips)</th>
                        <th style="text-align:center;">\(lFiles)</th>
                        <th style="text-align:right;">\(lUsed)</th>
                        <th>\(lDevType)</th>
                    </tr>
                </thead>
                <tbody>
                    \(renameRows)
                </tbody>
            </table>
            """
        }
        
        // MARK: - Section 2: ParaShoot Rows
        var parashootRows = ""
        if let events = parashootReport?.events {
            for event in events {
                let statusColor: String
                let statusText: String
                if !event.isVerificationKnown {
                    statusColor = "#a16207"
                    statusText = isCN ? "未知（未找到校验结果）" : "UNKNOWN (No verification result)"
                } else if event.isSafe {
                    statusColor = "#059669"
                    statusText = lPassed
                } else {
                    statusColor = "#dc2626"
                    statusText = isCN ? "警告（\(event.missingFilesCount) 个文件缺失）" : "WARNING (\(event.missingFilesCount) Missing)"
                }
                let associationCell = includeHighConfidenceAssociation
                    ? "<td>\(htmlEscape(event.isHighConfidenceAssociation ? lHighConfidence : lAssociationUnavailable))</td>"
                    : ""
                parashootRows += """
                <tr>
                    <td>\(htmlEscape(event.formattedDateTime))</td>
                    <td><strong>\(htmlEscape(event.volumeName))</strong></td>
                    <td>\(htmlEscape(event.deviceVendor)) \(htmlEscape(event.deviceModel))</td>
                    <td><code>\(htmlEscape(event.bsdUnit))</code></td>
                    <td style="color: \(statusColor); font-weight: bold;">\(htmlEscape(statusText))</td>
                    \(associationCell)
                </tr>
                """
            }
        }
        
        var parashootSection = ""
        if let events = parashootReport?.events, !events.isEmpty {
            let associationHeader = includeHighConfidenceAssociation ? "<th>\(lAssociation)</th>" : ""
            parashootSection = """
            <div class="section-title" style="margin-top: 30px;">\(lSec2Title)</div>
            <table>
                <thead>
                    <tr>
                        <th>\(lTime)</th>
                        <th>\(lVolName)</th>
                        <th>\(lDevInfo)</th>
                        <th>\(lTarget)</th>
                        <th>\(lVerify)</th>
                        \(associationHeader)
                    </tr>
                </thead>
                <tbody>
                    \(parashootRows)
                </tbody>
            </table>
            """
        }
        
        let reportTitle: String
        if renameItems.isEmpty {
            reportTitle = isCN ? "ParaShoot 擦卡审计报告" : "ParaShoot Erase Audit"
        } else if parashootReport == nil || parashootReport?.events.isEmpty == true {
            reportTitle = isCN ? "DIT 卡卷重命名审计" : "DIT Volume Rename Audit"
        } else {
            reportTitle = isCN ? "DIT 统一日常审计报告" : "DIT Unified Daily Audit"
        }
        let subTitle = isCN ? "卡卷重命名与 ParaShoot 擦卡审计综合报告" : "Media Volume Renaming & ParaShoot Erase Audit Report"
        
        let printFormatter = DateFormatter()
        printFormatter.locale = Locale(identifier: isCN ? "zh_CN" : "en_US")
        printFormatter.dateStyle = .medium
        printFormatter.timeStyle = .medium
        let printedTime = printFormatter.string(from: Date())
        let documentLanguage = isCN ? "zh-CN" : "en"
        
        return """
        <!DOCTYPE html>
        <html lang="\(documentLanguage)">
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; color: #1e293b; margin: 40px; }
                .header { border-bottom: 2px solid #0f172a; padding-bottom: 15px; margin-bottom: 25px; display: flex; justify-content: space-between; align-items: flex-end; }
                .title { font-size: 24px; font-weight: 800; margin: 0; letter-spacing: -0.5px; color: #0f172a; }
                .subtitle { font-size: 13px; color: #64748b; margin: 4px 0 0 0; text-transform: uppercase; letter-spacing: 0.8px; }
                .meta-info { text-align: right; font-size: 12px; color: #334155; line-height: 1.6; }
                .section-title { font-size: 14px; font-weight: 700; color: #1e293b; border-left: 4px solid #2563eb; padding-left: 8px; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.5px; }
                table { width: 100%; border-collapse: collapse; margin-top: 8px; font-size: 11px; }
                th { background-color: #f8fafc; border-top: 1px solid #cbd5e1; border-bottom: 2px solid #94a3b8; padding: 10px 8px; text-align: left; color: #475569; text-transform: uppercase; font-size: 10px; letter-spacing: 0.5px; }
                td { border-bottom: 1px solid #f1f5f9; padding: 10px 8px; vertical-align: middle; }
                code { background-color: #f1f5f9; padding: 2px 5px; border-radius: 4px; font-size: 10px; color: #0f172a; }
                .badge-blue { background-color: #eff6ff; color: #1d4ed8; padding: 2px 6px; border-radius: 4px; font-size: 10px; font-weight: 600; }
                .footer { margin-top: 50px; font-size: 10px; color: #94a3b8; text-align: center; border-top: 1px solid #e2e8f0; padding-top: 15px; }
                .lab-badge { display: inline-block; background-color: #0f172a; color: #fff; padding: 3px 8px; border-radius: 4px; font-size: 10px; font-weight: bold; margin-bottom: 6px; letter-spacing: 0.5px; }
            </style>
        </head>
        <body>
            <div class="header">
                <div>
                    <div class="lab-badge">\(htmlEscape(lBadge))</div>
                    <h1 class="title">\(htmlEscape(reportTitle))</h1>
                    <p class="subtitle">\(htmlEscape(subTitle))</p>
                </div>
                <div class="meta-info">
                    <strong>\(lDate):</strong> \(htmlEscape(dateStr))<br>
                    <strong>\(lRenamed):</strong> \(renameItems.count)<br>
                    <strong>\(lWiped):</strong> \(parashootReport?.events.count ?? 0)<br>
                    <strong>\(htmlEscape(lPrinted)):</strong> \(htmlEscape(printedTime))
                </div>
            </div>
            
            \(renameSection)
            \(parashootSection)
            
            <div class="footer">
                \(htmlEscape(lFooter))
            </div>
        </body>
        </html>
        """
    }
}
