import SwiftUI

@MainActor
struct CommunicationMessagesView: View {
    @Environment(AppSettings.self) private var appSettings
    @Environment(GatewayConnectionStore.self) private var store
    @State private var compose = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: V21Layout.spaceLG) {
                Text("显示 Gateway 最近已同步的短信；不发送、不删除，也不修改模块已读状态。")
                    .font(.subheadline).foregroundStyle(V21.textSecondary)
                if let error = store.messagesError {
                    Text(error).foregroundStyle(V21.textSecondary)
                }
                if !store.isConnected { Text("Gateway 未连接，记录可能不是最新。").foregroundStyle(V21.textSecondary) }
                if store.messages.isEmpty {
                    ContentUnavailableView("暂无已同步短信", systemImage: "message", description: Text("连接 Gateway 后下拉刷新。"))
                }
                ForEach(store.messages) { message in
                    NavigationLink(value: CommunicationRoute.message(message.id)) {
                        CommunicationCard {
                            VStack(alignment: .leading, spacing: V21Layout.spaceSM) {
                                Text(message.sender).font(.headline)
                                Text(message.body).font(.body).lineLimit(2)
                                Text(message.receivedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption).foregroundStyle(V21.textSecondary)
                                if message.isVerificationCode {
                                    Label("含验证码", systemImage: "number.square").font(.caption)
                                        .foregroundStyle(AppTheme.palette(named: appSettings.appThemeName).accent)
                                }
                            }
                            .privacySensitive()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("查看短信全文")
                }
            }
            .padding(V21Layout.pageMargin)
        }
        .background(V21.background)
        .foregroundStyle(V21.textPrimary)
        .navigationTitle("短信")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { compose = true } label: { Image(systemName: "square.and.pencil") }.disabled(!store.isConnected) } }
        .sheet(isPresented: $compose) { SMSComposeView() }
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refreshReadOnlyState() }
    }
}

@MainActor
private struct SMSComposeView: View {
    @Environment(GatewayConnectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var number = ""
    @State private var messageBody = ""
    @State private var state = ""
    var body: some View {
        NavigationStack { Form {
            TextField("手机号", text: $number).keyboardType(.phonePad)
            TextEditor(text: $messageBody).frame(minHeight: 140)
            if !state.isEmpty { Text(state).foregroundStyle(state == "发送成功" ? .green : .secondary) }
            Button("发送") {
                state = "发送中…"
                Task { let result = await store.sendSMS(number: number, body: messageBody); if case .success = result { state = "发送成功"; dismiss() } else { state = "发送失败" } }
            }.disabled(!store.isConnected || number.isEmpty || messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.navigationTitle("新短信").toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } } }
    }
}
