import SwiftUI

// MARK: - 玻璃表面（V2.1 核心组件）
// 半透明 + 细边框 + 材质模糊，克制的玻璃质感

struct GlassSurface<Content: View>: View {
    var elevated: Bool = false
    var radius: CGFloat = V21Layout.radiusLG
    var material: Material = .ultraThinMaterial
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(material)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(elevated ? V21.surfaceElevated : V21.surfaceGlass)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(V21.dividerStrong, lineWidth: 1)
            }
    }
}

// MARK: - 页面背景色场
// 极淡的双光斑氛围（左上品牌绿 6%、右下 info 4%），不染绿整个页面

struct PageBackground<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geo in
                    ZStack {
                        V21.background
                        RadialGradient(
                            colors: [V21.brandGreen.opacity(0.06), .clear],
                            center: UnitPoint(x: 0.08, y: 0.04),
                            startRadius: 0,
                            endRadius: geo.size.width * 0.95
                        )
                        RadialGradient(
                            colors: [V21.info.opacity(0.04), .clear],
                            center: UnitPoint(x: 0.92, y: 0.96),
                            startRadius: 0,
                            endRadius: geo.size.width * 0.85
                        )
                    }
                    .ignoresSafeArea()
                }
            }
    }
}

// MARK: - 优先级色点（2 高/红 1 中/蓝 0 低/灰）

struct PriorityDot: View {
    let level: Int
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }

    private var color: Color {
        switch level {
        case 2: return V21.danger
        case 1: return V21.info
        default: return V21.textQuaternary
        }
    }
}

// MARK: - 区块标题行（左标题 + 右侧可选动作）

struct SectionHeader: View {
    @Environment(AppSettings.self) private var settings
    let title: String
    var color: Color = V21.textPrimary
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .v21Style(.titleLarge)
                .foregroundColor(color)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .v21Style(.labelMedium)
                        .foregroundColor(AppTheme.palette(named: settings.appThemeName).accent)
                }
            }
        }
        .padding(.horizontal, V21Layout.pageMargin)
    }
}

// MARK: - 玻璃胶囊 Tab（待办 / 备忘 / 客户 等过滤）

struct PillTabRow<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    @Binding var selection: Item

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    let selected = item == selection
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selection = item }
                        Haptic.light()
                    } label: {
                        Text(label(item))
                            .v21Style(.labelLarge)
                            .foregroundColor(selected ? V21.textPrimary : V21.tabInactive)
                            .fontWeight(selected ? .semibold : .medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(selected ? AnyShapeStyle(V21.surfaceElevated) : AnyShapeStyle(.clear))
                            }
                            .overlay {
                                if selected {
                                    Capsule(style: .continuous)
                                        .strokeBorder(V21.dividerStrong, lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, V21Layout.pageMargin)
        }
    }
}

// MARK: - Floating FAB（品牌绿渐变方块）

struct V21FAB: View {
    @Environment(AppSettings.self) private var settings
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button {
            Haptic.medium()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: V21Layout.fabSize, height: V21Layout.fabSize)
                .background(
                    RoundedRectangle(cornerRadius: V21Layout.radiusLG, style: .continuous)
                        .fill(AppTheme.palette(named: settings.appThemeName).heroGradient)
                )
                .shadow(color: AppTheme.palette(named: settings.appThemeName).accent.opacity(0.24), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(V21.textQuaternary)
            }
            Text(text)
                .v21Style(.bodyMedium)
                .foregroundColor(V21.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }
}
