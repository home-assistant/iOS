import Shared
import SwiftUI

/// A settings row with a predefined list of values rendered as a menu picker
/// (`WebhookSensorSetting.SettingType.options`).
struct SensorDetailOptionsRow: View {
    let title: String
    let values: [Double]
    let displayValueFor: (Double) -> String
    let getter: () -> Double
    let setter: (Double) -> Void

    @State private var value: Double = 0

    var body: some View {
        Picker(title, selection: $value) {
            ForEach(values, id: \.self) { option in
                Text(displayValueFor(option)).tag(option)
            }
        }
        .pickerStyle(.menu)
        .onAppear {
            // Snap to the closest predefined value so a previously stored
            // out-of-list value still selects something sensible.
            let current = getter()
            value = values.min(by: { abs($0 - current) < abs($1 - current) }) ?? current
        }
        .onChange(of: value) { newValue in
            setter(newValue)
        }
    }
}

#Preview {
    List {
        SensorDetailOptionsRow(
            title: "Clear delay",
            values: [2, 5, 15, 30, 60, 120, 300],
            displayValueFor: { "\(Int($0)) s" },
            getter: { 15 },
            setter: { _ in }
        )
    }
}
