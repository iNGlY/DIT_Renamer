import Combine
import Foundation

@MainActor
final class LabelTemplateStore: ObservableObject {
    @Published private(set) var templates: [LabelTemplate]
    @Published var selectedTemplateID: String {
        didSet { UserDefaults.standard.set(selectedTemplateID, forKey: Self.selectedTemplateKey) }
    }

    private static let customTemplatesKey = "ditPrinter.customLabelTemplates"
    private static let selectedTemplateKey = "ditPrinter.selectedLabelTemplate"

    init() {
        let customTemplates: [LabelTemplate]
        if let data = UserDefaults.standard.data(forKey: Self.customTemplatesKey),
           let decoded = try? JSONDecoder().decode([LabelTemplate].self, from: data) {
            customTemplates = decoded.filter { !$0.isBuiltIn }
        } else {
            customTemplates = []
        }
        let allTemplates = LabelTemplate.builtIns + customTemplates
        templates = allTemplates
        let savedID = UserDefaults.standard.string(forKey: Self.selectedTemplateKey) ?? LabelTemplate.defaultTemplate.id
        selectedTemplateID = allTemplates.contains(where: { $0.id == savedID }) ? savedID : LabelTemplate.defaultTemplate.id
    }

    var selectedTemplate: LabelTemplate {
        templates.first(where: { $0.id == selectedTemplateID }) ?? LabelTemplate.defaultTemplate
    }

    func save(name: String, widthMm: Double?, heightMm: Double?, gapMm: Double?) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "Enter a template name." }
        guard let widthMm, (20...80).contains(widthMm) else { return "Width must be between 20 and 80 mm." }
        guard let heightMm, (20...100).contains(heightMm) else { return "Height must be between 20 and 100 mm." }
        guard let gapMm, (0...10).contains(gapMm) else { return "Gap must be between 0 and 10 mm." }

        let existing = selectedTemplate
        let template = LabelTemplate(
            id: existing.isBuiltIn ? "custom-\(UUID().uuidString)" : existing.id,
            name: trimmedName,
            widthMm: widthMm,
            heightMm: heightMm,
            gapMm: gapMm
        )
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        selectedTemplateID = template.id
        persistCustomTemplates()
        return nil
    }

    func deleteSelectedCustomTemplate() {
        guard !selectedTemplate.isBuiltIn else { return }
        templates.removeAll { $0.id == selectedTemplateID }
        selectedTemplateID = LabelTemplate.defaultTemplate.id
        persistCustomTemplates()
    }

    private func persistCustomTemplates() {
        let customTemplates = templates.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(customTemplates) {
            UserDefaults.standard.set(data, forKey: Self.customTemplatesKey)
        }
    }
}
