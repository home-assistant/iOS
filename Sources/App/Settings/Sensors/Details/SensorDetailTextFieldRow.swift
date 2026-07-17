import Shared
import SwiftUI

/// A settings row with a free-text field (`WebhookSensorSetting.SettingType.textField`).
/// The value is committed when the field loses focus, on submit, or when the view goes
/// away. Set `isSecure` to mask the input (e.g. a password).
struct SensorDetailTextFieldRow: View {
    let title: String
    let placeholder: String
    let isSecure: Bool
    let getter: () -> String
    let setter: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            field
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 180)
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { focused in
                    if !focused {
                        commit()
                    }
                }
                .autocorrectionDisabled()
            #if !os(watchOS)
                .textInputAutocapitalization(.never)
            #endif
        }
        .onAppear {
            text = getter()
        }
        .onDisappear {
            commit()
        }
    }

    @ViewBuilder private var field: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
        } else {
            TextField(placeholder, text: $text)
        }
    }

    private func commit() {
        setter(text)
    }
}

#Preview {
    List {
        SensorDetailTextFieldRow(
            title: "Username",
            placeholder: "Optional",
            isSecure: false,
            getter: { "kiosk" },
            setter: { _ in }
        )
        SensorDetailTextFieldRow(
            title: "Password",
            placeholder: "Optional",
            isSecure: true,
            getter: { "secret" },
            setter: { _ in }
        )
    }
}
