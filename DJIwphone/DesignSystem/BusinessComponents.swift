import SwiftUI

struct BusinessMetricView: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(V21.textSecondary)
            Text(value).font(.system(.largeTitle, design: .rounded).weight(.bold)).minimumScaleFactor(0.65)
            HStack(spacing: 6) { Circle().fill(tint).frame(width: 6, height: 6); Text(detail).font(.caption.weight(.medium)).foregroundStyle(V21.textTertiary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(V21.divider, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct BusinessSectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?
    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) { self.title = title; self.actionTitle = actionTitle; self.action = action }
    var body: some View {
        HStack(alignment: .firstTextBaseline) { Text(title).font(.title3.weight(.bold)).foregroundStyle(V21.textPrimary); Spacer(); if let actionTitle, let action { Button(actionTitle, action: action).font(.subheadline.weight(.semibold)) } }
    }
}
