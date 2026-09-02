import SwiftUI

struct CommunicationCallRow: View {
    let call: GatewayCall

    var body: some View {
        VStack(alignment: .leading, spacing: V21Layout.spaceSM) {
            Text(call.number ?? "未知号码").font(.headline).privacySensitive()
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("\(call.directionTitle) · \(call.stateTitle)")
                    Spacer()
                    Text(call.timestamp, format: .dateTime.month().day().hour().minute())
                }
                VStack(alignment: .leading) {
                    Text("\(call.directionTitle) · \(call.stateTitle)")
                    Text(call.timestamp, format: .dateTime.month().day().hour().minute())
                }
            }
            .font(.subheadline).foregroundStyle(V21.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, V21Layout.spaceSM)
    }
}
