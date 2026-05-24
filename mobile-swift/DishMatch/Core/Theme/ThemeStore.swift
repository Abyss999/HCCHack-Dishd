import SwiftUI

final class ThemeStore: ObservableObject {
    enum Mode: String, CaseIterable {
        case light, dark, system
    }

    @Published var mode: Mode = .system

    private let key = "dishd_theme_mode"

    init() {
        if let stored = UserDefaults.standard.string(forKey: key),
           let resolved = Mode(rawValue: stored) {
            mode = resolved
        }
    }

    func setMode(_ m: Mode) {
        mode = m
        UserDefaults.standard.set(m.rawValue, forKey: key)
    }

    func resolved(system: ColorScheme) -> ColorScheme {
        switch mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return system
        }
    }
}
