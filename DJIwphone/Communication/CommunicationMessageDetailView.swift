import SwiftUI

@MainActor
struct CommunicationMessageDetailView: View {
    @Environment(GatewayConnectionStore.self) private var store
    let messageID: String

    var body: some View {
        ScrollView {
            if let message = store.messages.first(where: { $0.id == messageID }) {
                CommunicationCard {
                    VStack(alignment: .leading, spacing: V21Layout.spaceLG) {
                        Text(message.sender).font(.headline)
                        Text(message.receivedAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.subheadline).foregroundStyle(V21.textSecondary)
                        Divider()
                        Text(message.body).font(.body).textSelection(.enabled)
                    }
                    .privacySensitive()
                }
                .padding(V21Layout.pageMargin)
            } else {
                ContentUnavailableView("短信未在当前列表中", systemImage: "message", description: Text("返回短信列表刷新后重试。"))
            }
        }
        .background(V21.background)
        .foregroundStyle(V21.textPrimary)
        .navigationTitle("短信详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
