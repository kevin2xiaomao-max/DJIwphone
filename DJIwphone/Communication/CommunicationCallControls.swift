import SwiftUI

@MainActor
struct CommunicationCallControls: View {
    @Environment(GatewayConnectionStore.self) private var store
    @State private var showsDialer = false

    var body: some View {
        CommunicationCard {
            VStack(alignment: .leading, spacing: V21Layout.spaceMD) {
                Text("当前通话").font(.headline)
                if store.isConnected, let call = store.currentCall {
                    QDC507CallView(call: call,
                        onAnswer: { Task { await store.performCallAction(.answer, call: call) } },
                        onHangup: { Task { await store.performCallAction(.hangup, call: call) } })
                    CommunicationCallRow(call: call)
                    if call.state == "incoming", call.direction == "incoming" {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 16) {
                                CallActionButton(action: .reject, call: call)
                                CallActionButton(action: .answer, call: call)
                            }
                            VStack(spacing: 12) {
                                CallActionButton(action: .answer, call: call)
                                CallActionButton(action: .reject, call: call)
                            }
                        }
                    } else if ["active", "dialing", "alerting"].contains(call.state) {
                        CallActionButton(action: .hangup, call: call)
                    }
                } else {
                    Label(store.isConnected ? "暂无进行中的通话" : "连接后显示当前通话", systemImage: "phone")
                        .foregroundStyle(V21.textSecondary)
                    Button("拨号", systemImage: "circle.grid.3x3.fill") { showsDialer = true }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                        .disabled(!store.canPerform(.dial))
                }
                if store.callActionInFlight { ProgressView("正在提交，请勿重复操作…") }
                if let message = store.callActionMessage {
                    Text(message).font(.subheadline).foregroundStyle(V21.textSecondary)
                        .accessibilityLabel(message)
                }
                if store.isConnected, store.status?.allowedCallActions.isEmpty != false {
                    Text("Gateway 当前为只读模式，尚未开放电话控制。")
                        .font(.caption).foregroundStyle(V21.textSecondary)
                }
                Text("这里只控制蜂窝电话，通话声音尚未接入 iPhone。")
                    .font(.caption).foregroundStyle(V21.textSecondary)
            }
        }
        .sheet(isPresented: $showsDialer) { NavigationStack { CommunicationDialerView() } }
    }
}
