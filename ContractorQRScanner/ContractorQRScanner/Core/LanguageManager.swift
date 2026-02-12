import Combine
import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            Bundle.setLanguage(currentLanguage)
            objectWillChange.send()
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        self.currentLanguage = saved
        Bundle.setLanguage(saved)
    }

    var isArabic: Bool {
        currentLanguage == "ar"
    }

    var layoutDirection: LayoutDirection {
        isArabic ? .rightToLeft : .leftToRight
    }

    func toggleLanguage() {
        currentLanguage = isArabic ? "en" : "ar"
    }

    func setLanguage(_ code: String) {
        currentLanguage = code
    }
}

// MARK: - Bundle extension for in-app language switching

private var bundleKey: UInt8 = 0

final class BundleExtension: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, BundleExtension.self)
        }

        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap { Bundle(path: $0) }
        objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
