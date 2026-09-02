import SwiftUI

// MARK: - V2.1 Design Tokens — Spacing / Radius / Sizes
// 对齐 Android V21 Spacing.kt

enum V21Layout {
    // ========== 页面布局 ==========
    static let pageMargin: CGFloat = 24       // 页面左右边距
    static let bottomDockContentGap: CGFloat = 120 // 内容底部为浮动 Dock 留白

    // ========== Section 间距 ==========
    static let spaceXS: CGFloat = 4
    static let spaceSM: CGFloat = 8
    static let spaceMD: CGFloat = 12
    static let spaceLG: CGFloat = 16
    static let spaceXL: CGFloat = 20
    static let spaceXXL: CGFloat = 28
    static let spaceXXXL: CGFloat = 32

    // ========== 圆角 ==========
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
    static let radiusPill: CGFloat = 20
    static let radiusDock: CGFloat = 28

    // ========== 组件尺寸 ==========
    static let dockHeight: CGFloat = 67
    static let centralVoiceButton: CGFloat = 53
    static let fabSize: CGFloat = 52
    static let listItemMinHeight: CGFloat = 52
    static let quickEntryIconBox: CGFloat = 52
}
