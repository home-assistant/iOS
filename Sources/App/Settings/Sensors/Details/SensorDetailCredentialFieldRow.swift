import Shared
import SwiftUI

/// One field of a `.credentials` setting, on its own row. Edits go to the shared
/// `CredentialsDraft` and are only persisted when the Save row is tapped.
struct SensorDetailCredentialFieldRow: View {
    @ObservedObject var draft: CredentialsDraft
    let index: Int

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(draft.fields[index].title)
                .frame(maxWidth: .infinity, alignment: .leading)
            field
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 200)
                .focused($isFocused)
                .autocorrectionDisabled()
            #if !os(watchOS)
                .textInputAutocapitalization(.never)
            #endif
        }
    }

    @ViewBuilder private var field: some View {
        let placeholder = draft.fields[index].placeholder ?? ""
        let binding = Binding(
            get: { draft.values.indices.contains(index) ? draft.values[index] : "" },
            set: { newValue in
                if draft.values.indices.contains(index) {
                    draft.values[index] = newValue
                }
            }
        )
        if draft.fields[index].isSecure {
            SecureField(placeholder, text: binding)
        } else {
            TextField(placeholder, text: binding)
        }
    }
}

#Preview {
    let draft = CredentialsDraft(fields: [
        .init(title: "Username", placeholder: "Optional", getter: { "kiosk" }, setter: { _ in }),
        .init(title: "Password", placeholder: "Optional", isSecure: true, getter: { "" }, setter: { _ in }),
    ])
    return List {
        SensorDetailCredentialFieldRow(draft: draft, index: 0)
        SensorDetailCredentialFieldRow(draft: draft, index: 1)
    }
}
