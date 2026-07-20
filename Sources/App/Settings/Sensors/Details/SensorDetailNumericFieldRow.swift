import Shared
import SwiftUI

/// A settings row with an integer text field using the number pad keyboard
/// (`WebhookSensorSetting.SettingType.numericField`). The value is committed when
/// the field loses focus or the user submits, clamped to the allowed range;
/// invalid input reverts to the current value.
struct SensorDetailNumericFieldRow: View {
    let title: String
    let minimum: Double
    let maximum: Double
    let getter: () -> Double
    let setter: (Double) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", text: $text)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { focused in
                    if !focused {
                        commit()
                    }
                }
            #if !os(watchOS)
                .keyboardType(.numberPad)
            #endif
        }
        .onAppear {
            text = String(Int(getter()))
        }
        .onDisappear {
            // Commit pending input even when the view goes away with the field
            // still focused (e.g. navigating back with the keyboard up).
            commit()
        }
    }

    private func commit() {
        guard let value = Double(text.filter(\.isNumber)) else {
            text = String(Int(getter()))
            return
        }
        let clamped = min(max(value, minimum), maximum)
        setter(clamped)
        text = String(Int(clamped))
    }
}

#Preview {
    List {
        SensorDetailNumericFieldRow(
            title: "Stream port",
            minimum: 1024,
            maximum: 65535,
            getter: { 8090 },
            setter: { _ in }
        )
    }
}
