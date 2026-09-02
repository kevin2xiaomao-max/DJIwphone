import SwiftUI

// Local reuse of existing surfaces/spacing. No global theme changes.
struct CommunicationCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(V21Layout.spaceXL)
            .background(V21.surfaceElevated, in: RoundedRectangle(cornerRadius: V21Layout.radiusXL))
            .overlay {
                RoundedRectangle(cornerRadius: V21Layout.radiusXL).strokeBorder(V21.divider, lineWidth: 1)
            }
    }
}
