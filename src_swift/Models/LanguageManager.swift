import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh"
    case en = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("appLanguage") var currentLanguageRaw: String = "" {
        didSet {
            objectWillChange.send()
        }
    }
    
    var currentLanguage: AppLanguage {
        get {
            if currentLanguageRaw.isEmpty {
                // Auto-detect system language
                let sysLang = Locale.current.language.languageCode?.identifier ?? "zh"
                return sysLang.lowercased().starts(with: "en") ? .en : .zh
            }
            return AppLanguage(rawValue: currentLanguageRaw) ?? .zh
        }
        set {
            currentLanguageRaw = newValue.rawValue
        }
    }
    
    func text(_ zh: String, _ en: String) -> String {
        return currentLanguage == .en ? en : zh
    }
}
