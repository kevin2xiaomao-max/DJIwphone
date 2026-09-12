import SwiftUI

@MainActor
struct GatewaySettingsView: View {
    @Environment(GatewayConnectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let settings: GatewaySettingsStore
    @State private var address = ""
    @State private var token = ""
    @State private var feedback: String?
    @State private var isTesting = false
    @State private var testTask: Task<Void, Never>?
    @StateObject private var webRTCClient = ForegroundWebRTCClient()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text("Gateway 地址").font(.subheadline)
                    TextField("http://192.168.1.97:17576", text: $address)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Gateway 地址")
                }
                VStack(alignment: .leading) {
                    Text("Bearer Token").font(.subheadline)
                    SecureField("输入 Token，或留空保留已保存值", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()
                        .accessibilityLabel("Bearer Token")
                }
            } header: {
                Text("连接配置")
            } footer: {
                Text("Token 仅保存在这台 iPhone 的 Keychain，不同步到 iCloud。相同地址留空可保留已存 Token；更换地址后请重新输入。")
            }
            .disabled(isTesting)

            Section {
                Button("保存配置", action: save).disabled(isTesting)
                Button("测试连接", action: test).disabled(isTesting)
                if isTesting { ProgressView("正在验证 HTTP 与 WebSocket…") }
                if let feedback { Text(feedback).accessibilityLabel(feedback) }
            } footer: {
                Text("测试使用当前填写的内容，不自动保存。只读取 /api/status 和 /ws，不执行电话或短信操作。")
            }

            Section("设备详情") {
                LabeledContent("Gateway", value: store.isConnected ? "在线" : "未连接")
                if let status = store.status {
                    LabeledContent("SIM", value: status.simState ?? "未知")
                    LabeledContent("运营商", value: status.operatorName ?? "未知")
                    LabeledContent("信号原始值", value: status.signalStrength ?? "未知")
                    LabeledContent("网络注册原始值", value: status.registration ?? "未知")
                    LabeledContent("网络制式", value: status.networkType ?? "未知")
                }
                if !store.isConnected {
                    Text("以下信息以最近同步为准，可能已过期。").foregroundStyle(.secondary)
                }
            }

            Section("当前功能") {
                Text("电话按钮以 Gateway 开放的权限为准，操作需由你手动点击。短信仅供查看，暂不提供通话音频。")
                Text("尚未提供可靠的未接来电和未读短信统计，因此不显示数量。")
            }

            Section {
                Button("开始测试", action: startWebRTCTest)
                    .disabled(isTesting || webRTCClient.phase == .connecting || webRTCClient.phase == .connected)
                Button("停止测试", action: webRTCClient.stop)
                    .disabled(webRTCClient.phase == .stopped)
                LabeledContent("Peer state", value: webRTCClient.peerState)
                LabeledContent("当前阶段", value: webRTCClient.phase.rawValue)
                LabeledContent("ICE state", value: webRTCClient.iceState)
                LabeledContent("本地 ICE candidates", value: "\(webRTCClient.localCandidateCount)")
                LabeledContent("远端音频", value: webRTCClient.remoteAudioReceived ? "已收到" : "未收到")
                if let error = webRTCClient.lastError {
                    Text(error).foregroundStyle(.red).accessibilityLabel(error)
                }
            } header: {
                Text("WebRTC 音频测试")
            } footer: {
                Text("仅用于前台双向测试音频，不连接 QDC507 PCM，不影响正式通话。")
            }

            Section("安全提示") {
                Text("当前默认 HTTP 不加密传输 Token 与数据，只能在可信的同一 Wi-Fi 使用，不能用于公网。Keychain 仅保护本机存储。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Gateway 设置")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("完成", action: finish) }
        }
        .onAppear { address = settings.savedAddress }
        .onChange(of: address) { _, _ in clearTestSuccess() }
        .onChange(of: token) { _, _ in clearTestSuccess() }
        .onDisappear {
            cancelTest()
            webRTCClient.stop()
        }
    }

    private func save() {
        do {
            try settings.save(address: address, token: token)
            store.restart(settings: settings)
            address = settings.savedAddress
            token = ""
            feedback = "配置已保存。返回通信页后会使用该配置连接。"
        } catch { feedback = GatewayClientError.safeMessage(for: error) }
    }

    private func clearTestSuccess() {
        if feedback == "QDC507 已连接" { feedback = nil }
    }

    private func test() {
        testTask?.cancel()
        feedback = nil
        isTesting = true
        // Input is disabled for the lifetime of this test; the credential is memory-only until Save.
        testTask = Task { @MainActor in
            defer { isTesting = false }
            do {
                let configuration = try settings.configuration(address: address, token: token)
                let client = URLSessionGatewayClient(configuration: configuration)
                try await client.validateConnection()
                try Task.checkCancellation()
                feedback = "QDC507 已连接"
            } catch {
                guard !Task.isCancelled else { return }
                feedback = GatewayClientError.safeMessage(for: error)
            }
        }
    }

    private func cancelTest() {
        testTask?.cancel()
        testTask = nil
        token = ""
    }

    private func startWebRTCTest() {
        Task { @MainActor in
            do {
                let configuration = try settings.configuration(address: address, token: token)
                await webRTCClient.start(configuration: configuration)
            } catch {
                feedback = GatewayClientError.safeMessage(for: error)
            }
        }
    }

    private func finish() {
        cancelTest()
        dismiss()
    }
}
