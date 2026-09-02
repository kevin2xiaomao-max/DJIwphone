import SwiftUI

// MARK: - Floating Dock（主底部导航）
// 4 个 Tab + 中央语音突出按钮；玻璃胶囊浮层

enum AppTab: Hashable {
    case home, performance, todo, profile

    var title: String {
        switch self {
        case .home: return "首页"
        case .performance: return "业绩"
        case .todo: return "待办"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .todo: return "checkmark"
        case .profile: return "person.fill"
        }
    }
}

struct FloatingDock: View {
    @Binding var selection: AppTab
    var showsVoiceButton: Bool = true
    var onVoice: () -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme

    private let tabs: [AppTab] = [.home, .performance, .todo, .profile]

    var body: some View {
        HStack(spacing: 0) {
            dockItem(.home)
            dockItem(.todo)
            if showsVoiceButton {
                centralVoice
            }
            dockItem(.performance)
            dockItem(.profile)
        }
        .padding(.horizontal, 5)
        .frame(height: 67)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(Color.white.opacity(0.08)))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(V21.dividerStrong, lineWidth: 1)
        }
        .padding(.horizontal, V21Layout.pageMargin)
        .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 5)
    }

    // 普通导航项
    @ViewBuilder
    private func dockItem(_ tab: AppTab) -> some View {
        let selected = selection == tab
        Button {
            guard selection != tab else { return }
            selection = tab
            Haptic.light()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolEffect(.bounce, value: selected)
                Text(tab.title)
                    .font(.system(size: 10, weight: selected ? .semibold : .medium))
            }
            .foregroundColor(selected ? AppTheme.palette(named: settings.appThemeName).accent : (colorScheme == .dark ? Color.white.opacity(0.62) : V21.tabInactive))
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(AppTheme.palette(named: settings.appThemeName).selectedBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, -3)
                }
            }
            .scaleEffect(selected ? 1.06 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: selected)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // 中央语音按钮：蓝紫渐变玻璃圆钮，上浮
    private var centralVoice: some View {
        Button {
            Haptic.medium()
            onVoice()
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 53, height: 53)
                .background(Circle().fill(AppTheme.palette(named: settings.appThemeName).heroGradient))
                .overlay(Circle().fill(.white.opacity(0.08)))
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: AppTheme.palette(named: settings.appThemeName).accent.opacity(0.28), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .offset(y: -5)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 触感反馈

import UIKit

enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
