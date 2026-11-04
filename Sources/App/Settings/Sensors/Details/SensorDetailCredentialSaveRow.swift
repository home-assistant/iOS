import Shared
import SwiftUI

/// The Save row for a `.credentials` setting: a full-width button that commits every
/// field of the shared `CredentialsDraft` at once, enabled only when there are changes.
struct SensorDetailCredentialSaveRow: View {
    @ObservedObject var draft: CredentialsDraft
    let footer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Button(action: draft.save) {
                Text(L10n.saveLabel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!draft.hasChanges)
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    List {
        SensorDetailCredentialSaveRow(
            draft: CredentialsDraft(fields: [
                .init(title: "Username", getter: { "kiosk" }, setter: { _ in }),
            ]),
            footer: "Leave blank to allow anyone on your network to view the stream."
        )
    }
}
