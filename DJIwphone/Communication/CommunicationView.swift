import SwiftUI

@MainActor
struct CommunicationView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(GatewaySettingsStore.self) private var settings
    @Environment(GatewayConnectionStore.self) private var store
    @State private var tab: Tab = .calls
    @State private var showsGatewaySettings = false

    private var accent: Color { AppTheme.palette(named: appSettings.appThemeName).accent }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { home }.tabItem { Label("通话", systemImage: "phone") }.tag(Tab.calls)
            NavigationStack { CommunicationDialerView() }.tabItem { Label("拨号", systemImage: "circle.grid.3x3.fill") }.tag(Tab.dialer)
            NavigationStack { CommunicationMessagesView() }.tabItem { Label("短信", systemImage: "message") }.tag(Tab.messages)
            NavigationStack { settingsView }.tabItem { Label("设置", systemImage: "gearshape") }.tag(Tab.settings)
        }
        .tint(accent)
        .navigationDestination(for: CommunicationRoute.self) { route in
            switch route {
            case .messages: CommunicationMessagesView()
            case .calls: CommunicationCallsView()
            case .message(let id): CommunicationMessageDetailView(messageID: id)
            }
        }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                deviceHeader
                if let call = store.currentCall, store.isConnected {
                    QDC507CallView(call: call,
                        onAnswer: { Task { await store.performCallAction(.answer, call: call) } },
                        onHangup: { Task { await store.performCallAction(.hangup, call: call) } })
                } else { recentCalls }
                quickActions
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 24)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("QDC507").navigationBarTitleDisplayMode(.large)
        .refreshable { await store.refreshReadOnlyState() }
    }

    private var deviceHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: store.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.title3.weight(.semibold)).foregroundStyle(store.isConnected ? .green : .secondary)
                .frame(width: 40, height: 40).background(.thinMaterial, in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.isConnected ? "已连接" : "未连接").font(.subheadline.weight(.semibold))
                Text(store.status?.operatorName ?? "Gateway 等待同步").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Label(store.isConnected ? "在线" : "离线", systemImage: "circle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(store.isConnected ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.isConnected ? "QDC507，已连接" : "QDC507，未连接")
    }

    private var recentCalls: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("最近通话") { tab = .calls }
            if store.calls.isEmpty {
                ContentUnavailableView("暂无通话记录", systemImage: "phone", description: Text(store.isConnected ? "新的通话记录会显示在这里" : "连接 Gateway 后同步记录"))
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                ForEach(store.calls.prefix(3)) { call in CommunicationCallRow(call: call) }
            }
        }
        .padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("快捷操作")
            HStack(spacing: 12) {
                actionTile("拨号", "circle.grid.3x3.fill", accent) { tab = .dialer }
                actionTile("短信", "message.fill", .blue) { tab = .messages }
            }
            Text("通话声音尚未接入 iPhone。").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var settingsView: some View {
        Form {
            Section("设备") { LabeledContent("设备", value: "QDC507"); LabeledContent("连接状态", value: store.isConnected ? "已连接" : "未连接") }
            Section("Gateway") { Button("Gateway 设置") { showsGatewaySettings = true }; LabeledContent("状态", value: store.isConnected ? "在线" : "离线") }
            Section("关于") { LabeledContent("版本", value: "0.2.0"); Text("QDC507 通信").foregroundStyle(.secondary) }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showsGatewaySettings) { NavigationStack { GatewaySettingsView(settings: settings) }.tint(accent) }
    }

    private func sectionHeader(_ title: String, action: (() -> Void)? = nil) -> some View {
        HStack { Text(title).font(.title3.weight(.bold)); Spacer(); if let action { Button("查看全部", action: action).font(.subheadline.weight(.semibold)) } }
    }

    private func actionTile(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48) }
            .buttonStyle(.bordered).tint(color).accessibilityLabel(title)
    }

    private enum Tab: Hashable { case calls, dialer, messages, settings }
}
