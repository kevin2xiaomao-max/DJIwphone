import SwiftUI

@MainActor
struct CommunicationDialerView: View {
    @Environment(GatewayConnectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var number = ""
    @State private var confirmsDial = false
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "0", "⌫"]
    private var validNumber: Bool {
        GatewayConfiguration.isValidDialNumber(number)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: V21Layout.spaceXL) {
                TextField("输入电话号码", text: $number)
                    .keyboardType(.phonePad).textContentType(.telephoneNumber)
                    .font(.title2).multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .privacySensitive().accessibilityLabel("拨打号码")
                    .disabled(store.callControlsBusy)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(keys, id: \.self) { key in
                        Button { enter(key) } label: {
                            Text(key).font(.title2).frame(maxWidth: .infinity, minHeight: 56)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(key == "⌫" ? "删除最后一位" : key)
                        .disabled(store.callControlsBusy)
                    }
                }
                Button("拨打", systemImage: "phone.fill") { confirmsDial = true }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(!validNumber || !store.canPerform(.dial))
                    .alert("确认拨打", isPresented: $confirmsDial) {
                        Button("取消", role: .cancel) { }
                        Button("确认拨打") { dial() }
                    } message: { Text(number).privacySensitive() }
                Text("拨号由 QDC507 内的 SIM 发起，可能产生运营商费用。本版不传输通话音频。")
                    .font(.subheadline).foregroundStyle(V21.textSecondary)
            }
            .padding(V21Layout.pageMargin)
        }
        .background(V21.background)
        .navigationTitle("拨号")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
    }

    private func enter(_ key: String) {
        if key == "⌫" { if !number.isEmpty { number.removeLast() }; return }
        if key == "+" { if number.isEmpty { number = "+" }; return }
        guard number.count < 16 else { return }
        number += key
    }

    private func dial() {
        guard validNumber, store.canPerform(.dial) else { return }
        let target = number
        Task { await store.performCallAction(.dial, number: target) }
        dismiss()
    }
}
