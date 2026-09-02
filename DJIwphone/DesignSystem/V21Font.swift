import SwiftUI

// MARK: - V2.1 Design Tokens — Typography
// 排版层级对齐 Android V21 Type.kt

enum V21TextStyle {
    case displayHero      // 72 首页营业额大数字
    case displayLarge     // 56 业绩页总营业额
    case titlePage        // 34 页面大标题
    case titleSection     // 22 区块大数字
    case titleLarge       // 18 卡片/Sheet 标题
    case titleMedium      // 16 列表项主标题
    case titleSmall       // 15 次级标题
    case bodyLarge        // 15 正文
    case bodyMedium       // 14 常规正文
    case bodySmall        // 13 辅助正文
    case labelLarge       // 13 标签
    case labelMedium      // 12 元信息
    case labelSmall       // 11 分组标题

    var font: Font { scaledFont(by: 1) }

    func scaledFont(by scale: CGFloat) -> Font {
        switch self {
        case .displayHero:  return .system(size: 72 * scale, weight: .bold)
        case .displayLarge: return .system(size: 56 * scale, weight: .bold)
        case .titlePage:    return .system(size: 34 * scale, weight: .bold)
        case .titleSection: return .system(size: 22 * scale, weight: .bold)
        case .titleLarge:   return .system(size: 18 * scale, weight: .semibold)
        case .titleMedium:  return .system(size: 16 * scale, weight: .semibold)
        case .titleSmall:   return .system(size: 15 * scale, weight: .medium)
        case .bodyLarge:    return .system(size: 15 * scale, weight: .regular)
        case .bodyMedium:   return .system(size: 14 * scale, weight: .regular)
        case .bodySmall:    return .system(size: 13 * scale, weight: .regular)
        case .labelLarge:   return .system(size: 13 * scale, weight: .medium)
        case .labelMedium:  return .system(size: 12 * scale, weight: .medium)
        case .labelSmall:   return .system(size: 11 * scale, weight: .semibold)
        }
    }

    /// 相对字号的字距（pt）
    var kerning: CGFloat {
        switch self {
        case .displayHero, .displayLarge: return -2.4
        case .titlePage:                  return -0.8
        case .titleSection:               return -0.4
        case .labelSmall:                 return 0.5
        default:                          return 0
        }
    }

    var lineSpacingProxy: CGFloat {
        switch self {
        case .displayHero, .displayLarge: return 0
        case .titlePage:                  return 4
        default:                          return 0
        }
    }
}

struct V21TextStyleModifier: ViewModifier {
    let style: V21TextStyle
    @ScaledMetric(relativeTo: .body) private var fontScale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .font(style.scaledFont(by: fontScale))
            .kerning(style.kerning)
    }
}

extension View {
    /// 应用 V2.1 排版层级
    func v21Style(_ style: V21TextStyle) -> some View {
        modifier(V21TextStyleModifier(style: style))
    }
}

// MARK: - 数字等宽（大金额对齐）
extension Font {
    /// 营业额等大数字使用 SF Pro，货币符号/数字混排时保持紧凑
    static var v21MoneyHero: Font { .system(size: 72, weight: .bold) }
    static var v21MoneyLarge: Font { .system(size: 56, weight: .bold) }
}

/// 全 App 统一字体层级，基于 iOS 系统字体，不引入外部字体依赖。
enum AppTypography {
    static let pageTitle = Font.system(size: 30, weight: .semibold, design: .rounded)
    static let sectionTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 16, weight: .medium)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodyMedium = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 12, weight: .regular)
    static let micro = Font.system(size: 11, weight: .medium)
    static let heroAmount = Font.system(size: 53, weight: .semibold, design: .rounded)
}
