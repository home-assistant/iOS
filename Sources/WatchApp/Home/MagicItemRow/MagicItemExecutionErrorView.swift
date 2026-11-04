import SFSafeSymbols
import Shared
import SwiftUI

/// Full-screen explanation shown when a magic item fails to execute, replacing a small alert so
/// the reason (and what to do about it) is readable on-device.
struct MagicItemExecutionErrorView: View {
    let itemName: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                Image(systemSymbol: .xmarkCircleFill)
                    .font(.system(size: 32))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(verbatim: L10n.Watch.Home.Run.Error.title)
                    .font(.headline)
                Text(verbatim: itemName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(verbatim: message)
                    .font(.footnote)
                Button {
                    onDismiss()
                } label: {
                    Text(verbatim: L10n.okLabel)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    MagicItemExecutionErrorView(
        itemName: "Good Morning",
        message: "“Home” has no URL this device can use right now.\n\nOpen Settings → Servers on this watch to review the server's URL options.",
        onDismiss: {}
    )
}
