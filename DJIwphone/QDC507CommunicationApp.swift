import SwiftUI

enum DJIwphoneIdentity {
    static let bundleIdentifier = "com.kevin2xiaomao.qdc507communication"
    static let displayName = "DJIwphone"
}

@main
struct DJIwphoneApp: App {
    @State private var settings = AppSettings.shared
    @State private var gatewaySettings = GatewaySettingsStore()
    @State private var gatewayConnection = GatewayConnectionStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CommunicationView()
            }
            .environment(settings)
            .environment(gatewaySettings)
            .environment(gatewayConnection)
            .tint(AppTheme.palette(named: settings.appThemeName).accent)
        }
    }
}
