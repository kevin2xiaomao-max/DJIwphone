import SwiftUI

@MainActor
struct HomeCommunicationEntry: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(GatewayConnectionStore.self) private var store

    var body: some View {
        NavigationLink(value: "communication") {
            CommunicationCard {
                HStack(spacing: V21Layout.spaceMD) {
                    Image(systemName: "phone.bubble.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.palette(named: appSettings.appThemeName).accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: V21Layout.spaceXS) {
                        Text("通信").font(.headline).foregroundStyle(V21.textPrimary)
                        Text(store.deviceConnectionTitle).font(.subheadline).foregroundStyle(V21.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(V21.textSecondary).accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开通信中心，查看设备、通话和短信")
    }
}
