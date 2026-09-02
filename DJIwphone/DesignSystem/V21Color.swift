import SwiftUI
import UIKit

// MARK: - V2.1 Design Tokens — Colors
// 语义完全对齐 Android V21 Color.kt（Light / Dark 双套）

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Light / Dark 动态色
    static func v21Dynamic(light: UInt32, dark: UInt32, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(hex: dark, alpha: darkAlpha)
            } else {
                return UIColor(hex: light, alpha: lightAlpha)
            }
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Token 常量

enum V21 {
    // ========== 品牌色（双主题一致） ==========
    static var brandGreen: Color { AppTheme.palette(named: AppSettings.shared.appThemeName).accent }
    static var brandGreenSoft: Color { AppTheme.palette(named: AppSettings.shared.appThemeName).accent }
    static var brandGreenDeep: Color { AppTheme.palette(named: AppSettings.shared.appThemeName).accentSecondary }
    static let warning = Color(hex: 0xFF9F0A)
    static let danger = Color(hex: 0xFF6B6B)
    static let info = Color(hex: 0x0A84FF)

    static var brandGreenGradient: LinearGradient { AppTheme.palette(named: AppSettings.shared.appThemeName).heroGradient }

    // ========== 背景 ==========
    static let background = Color.v21Dynamic(light: 0xF2F3F5, dark: 0x0A0C0E)
    static let backgroundSecondary = Color.v21Dynamic(light: 0xE8EAED, dark: 0x0D0F12)

    // ========== Surface 三级 ==========
    static let surfacePrimary = Color.v21Dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.5, darkAlpha: 0.035)
    static let surfaceGlass = Color.v21Dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.7, darkAlpha: 0.055)
    static let surfaceElevated = Color.v21Dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.85, darkAlpha: 0.07)

    // ========== 文字四级 ==========
    static let textPrimary = Color.v21Dynamic(light: 0x1A1D21, dark: 0xFFFFFF)
    static let textSecondary = Color.v21Dynamic(light: 0x3A3F47, dark: 0xFFFFFF, lightAlpha: 1, darkAlpha: 0.8)
    static let textTertiary = Color.v21Dynamic(light: 0x7D848E, dark: 0xFFFFFF, lightAlpha: 1, darkAlpha: 0.45)
    static let textQuaternary = Color.v21Dynamic(light: 0xB5BAC4, dark: 0xFFFFFF, lightAlpha: 1, darkAlpha: 0.28)

    // ========== 分割线 / 时间轴 ==========
    static let divider = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.09, darkAlpha: 0.05)
    static let dividerStrong = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.12, darkAlpha: 0.08)
    static let dividerHighlight = Color.v21Dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.9, darkAlpha: 0.12)
    static let timeline = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.16, darkAlpha: 0.16)
    static let timelineDotBorder = Color.v21Dynamic(light: 0x1E2328, dark: 0xFFFFFF, lightAlpha: 0.25, darkAlpha: 0.24)

    // ========== 分组标题 / 未选中 Tab ==========
    static let groupTitle = Color(hex: 0x737A84)
    static let tabInactive = Color(hex: 0x7C838D)

    // ========== 玻璃高光边 ==========
    static let glassHighlight = Color.v21Dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.8, darkAlpha: 0.06)
}

/// 全 App 主题令牌。默认 Blue Purple；其余主题预留给后续设置页选择。
struct AppThemePalette {
    let name: String
    let accent: Color
    let accentSecondary: Color
    let heroGradient: LinearGradient
    let selectedBackground: Color

    static let bluePurple = AppThemePalette(
        name: "Blue Purple",
        accent: Color(hex: 0x4C8DFF),
        accentSecondary: Color(hex: 0x7651D8),
        heroGradient: LinearGradient(colors: [Color(hex: 0x317CF5), Color(hex: 0x7651D8)], startPoint: .topLeading, endPoint: .bottomTrailing),
        selectedBackground: Color(hex: 0x4C8DFF).opacity(0.12)
    )
    static let graphite = AppThemePalette(name: "Graphite", accent: Color(hex: 0x8D9AA8), accentSecondary: Color(hex: 0x4C5966), heroGradient: LinearGradient(colors: [Color(hex: 0x46515C), Color(hex: 0x1D252D)], startPoint: .topLeading, endPoint: .bottomTrailing), selectedBackground: Color.white.opacity(0.1))
    static let glacierBlue = AppThemePalette(name: "Glacier Blue", accent: Color(hex: 0x47B6E8), accentSecondary: Color(hex: 0x6688F5), heroGradient: LinearGradient(colors: [Color(hex: 0x42B7E8), Color(hex: 0x6670E8)], startPoint: .topLeading, endPoint: .bottomTrailing), selectedBackground: Color(hex: 0x47B6E8).opacity(0.12))
    static let emerald = AppThemePalette(name: "Emerald", accent: Color(hex: 0x27C56F), accentSecondary: Color(hex: 0x168B68), heroGradient: LinearGradient(colors: [Color(hex: 0x35C98A), Color(hex: 0x187A75)], startPoint: .topLeading, endPoint: .bottomTrailing), selectedBackground: Color(hex: 0x27C56F).opacity(0.12))
    static let coral = AppThemePalette(name: "Coral", accent: Color(hex: 0xF07C6C), accentSecondary: Color(hex: 0xC84F7A), heroGradient: LinearGradient(colors: [Color(hex: 0xF08B6C), Color(hex: 0xC85682)], startPoint: .topLeading, endPoint: .bottomTrailing), selectedBackground: Color(hex: 0xF07C6C).opacity(0.12))
}

enum AppTheme {
    static let current = AppThemePalette.bluePurple

    static func palette(named name: String) -> AppThemePalette {
        switch name {
        case "Graphite": return .graphite
        case "Glacier Blue": return .glacierBlue
        case "Emerald": return .emerald
        case "Coral": return .coral
        default: return .bluePurple
        }
    }

    static let all: [AppThemePalette] = [.bluePurple, .graphite, .glacierBlue, .emerald, .coral]
}
