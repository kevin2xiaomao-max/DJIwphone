import SwiftUI

struct QDC507CallView: View {
    let call: GatewayCall
    let onAnswer: () -> Void
    let onHangup: () -> Void

    var body: some View {
        VStack(spacing: V21Layout.spaceMD) {
            Image(systemName: call.state == "incoming" ? "phone.arrow.down.left" : "phone.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(V21.brandGreen)
                .accessibilityLabel("QDC507 通话")
            Text(call.number ?? "未知来电").font(.title3.weight(.semibold))
            Text(call.stateTitle).foregroundStyle(V21.textSecondary)
            HStack(spacing: V21Layout.spaceMD) {
                if call.state == "incoming" {
                    Button("接听", systemImage: "phone.fill", action: onAnswer)
                        .buttonStyle(.borderedProminent)
                }
                if ["incoming", "active", "dialing", "alerting"].contains(call.state) {
                    Button("挂断", systemImage: "phone.down.fill", action: onHangup)
                        .tint(.red)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(V21Layout.pageMargin)
        .frame(maxWidth: .infinity)
        .background(V21.background)
    }
}
