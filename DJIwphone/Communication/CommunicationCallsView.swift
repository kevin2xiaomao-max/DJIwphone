import SwiftUI

@MainActor
struct CommunicationCallsView: View {
    @Environment(GatewayConnectionStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: V21Layout.spaceLG) {
                Text("仅展示 Gateway 已同步的最近记录，不把“已结束”自动判定为未接来电。")
                    .font(.subheadline).foregroundStyle(V21.textSecondary)
                if !store.isConnected { Text("Gateway 未连接，记录可能不是最新。").foregroundStyle(V21.textSecondary) }
                if store.calls.isEmpty {
                    ContentUnavailableView("暂无已同步通话", systemImage: "phone")
                }
                ForEach(store.calls) { call in
                    CommunicationCard { CommunicationCallRow(call: call) }
                }
            }
            .padding(V21Layout.pageMargin)
        }
        .background(V21.background)
        .foregroundStyle(V21.textPrimary)
        .navigationTitle("最近通话")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refreshReadOnlyState() }
    }
}
