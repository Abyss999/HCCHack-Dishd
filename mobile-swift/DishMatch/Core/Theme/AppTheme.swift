import SwiftUI

struct AppTheme {
    let bg: Color
    let surface: Color
    let surfaceLight: Color
    let text: Color
    let textSecondary: Color
    let textTertiary: Color
    let border: Color
    let primary: Color
    let primaryLight: Color
    let primaryMuted: Color
    let placeholderText: Color
    let inputBg: Color
    let inputBorder: Color
    let cardBg: Color
    let cardBorder: Color
    let chipBg: Color
    let chipBorder: Color
    let progressBg: Color
    let rankBadgeFallback: Color
    let rankBadgeFallbackText: Color
    let like: Color
    let pass: Color
    let destructive: Color
    let success: Color

    static let dark = AppTheme(
        bg:                   Color(hex: "#0a0a0a"),
        surface:              Color(hex: "#1a1a1a"),
        surfaceLight:         Color(hex: "#262626"),
        text:                 .white,
        textSecondary:        Color(hex: "#b3b3b3"),
        textTertiary:         Color(hex: "#808080"),
        border:               Color(hex: "#404040"),
        primary:              Color(hex: "#d97757"),
        primaryLight:         Color(hex: "#f5a76d"),
        primaryMuted:         Color(hex: "#d97757").opacity(0.15),
        placeholderText:      Color.white.opacity(0.4),
        inputBg:              Color(hex: "#1a1a1a").opacity(0.8),
        inputBorder:          Color(hex: "#d97757").opacity(0.25),
        cardBg:               Color(hex: "#1a1a1a"),
        cardBorder:           Color(hex: "#d97757").opacity(0.15),
        chipBg:               Color(hex: "#d97757").opacity(0.1),
        chipBorder:           Color(hex: "#d97757").opacity(0.2),
        progressBg:           Color(hex: "#d97757").opacity(0.2),
        rankBadgeFallback:    Color(hex: "#3d3d3d"),
        rankBadgeFallbackText: .white,
        like:                 Color(hex: "#4caf50"),
        pass:                 Color(hex: "#ef5350"),
        destructive:          Color(hex: "#ef5350"),
        success:              Color(hex: "#4caf50")
    )

    static let light = AppTheme(
        bg:                   Color(hex: "#faf9f7"),
        surface:              Color(hex: "#f2efeb"),
        surfaceLight:         Color(hex: "#e8e3dc"),
        text:                 Color(hex: "#1c1917"),
        textSecondary:        Color(hex: "#78716c"),
        textTertiary:         Color(hex: "#a8a29e"),
        border:               Color(hex: "#d6d0c8"),
        primary:              Color(hex: "#d97757"),
        primaryLight:         Color(hex: "#f5a76d"),
        primaryMuted:         Color(hex: "#d97757").opacity(0.12),
        placeholderText:      Color(hex: "#a8a29e"),
        inputBg:              Color(hex: "#f2efeb"),
        inputBorder:          Color(hex: "#d97757").opacity(0.3),
        cardBg:               Color(hex: "#f2efeb"),
        cardBorder:           Color(hex: "#d97757").opacity(0.15),
        chipBg:               Color(hex: "#d97757").opacity(0.08),
        chipBorder:           Color(hex: "#d97757").opacity(0.2),
        progressBg:           Color(hex: "#d97757").opacity(0.15),
        rankBadgeFallback:    Color(hex: "#e8e3dc"),
        rankBadgeFallbackText: Color(hex: "#1c1917"),
        like:                 Color(hex: "#4caf50"),
        pass:                 Color(hex: "#ef5350"),
        destructive:          Color(hex: "#ef5350"),
        success:              Color(hex: "#4caf50")
    )

    static func current(for scheme: ColorScheme) -> AppTheme {
        scheme == .dark ? .dark : .light
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
