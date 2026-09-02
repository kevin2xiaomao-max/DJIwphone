import SwiftUI

@MainActor
struct CallActionButton: View {
    @Environment(GatewayConnectionStore.self) private var store
    @Environment(AppSettings.self) private var settings
    let action: GatewayCallAction
    let call: GatewayCall

    var body: some View {
        Button(action.title, systemImage: action == .answer ? "phone.fill" : "phone.down.fill") {
            Task { await store.performCallAction(action, call: call) }
        }
        .buttonStyle(.borderedProminent)
        .tint(action == .answer ? AppTheme.palette(named: settings.appThemeName).accent : V21.danger)
        .controlSize(.large)
        .frame(minHeight: 44)
        .disabled(!store.canPerform(action, call: call))
    }
}
