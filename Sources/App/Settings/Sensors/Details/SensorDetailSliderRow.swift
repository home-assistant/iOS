import Shared
import SwiftUI

/// A settings row with a slider (`WebhookSensorSetting.SettingType.slider`). The value
/// is only committed when the drag ends, so setters with side effects (e.g. camera
/// reconfiguration) aren't hammered while sliding.
struct SensorDetailSliderRow: View {
    let title: String
    let minimum: Double
    let maximum: Double
    let step: Double
    let displayValueFor: ((Double?) -> String?)?
    let getter: () -> Double
    let setter: (Double) -> Void

    @State private var value: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Spaces.half) {
            HStack {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(displayValueFor?(value) ?? String(describing: value))
                    .foregroundColor(.secondary)
            }
            Slider(
                value: $value,
                in: minimum ... maximum,
                step: step
            ) { editing in
                if !editing {
                    setter(value)
                }
            }
        }
        .onAppear {
            value = getter()
        }
    }
}

#Preview {
    List {
        SensorDetailSliderRow(
            title: "Frame rate",
            minimum: 1,
            maximum: 30,
            step: 1,
            displayValueFor: { value in value.map { String(format: "%.0f fps", $0) } },
            getter: { 8 },
            setter: { _ in }
        )
        SensorDetailSliderRow(
            title: "Changed area threshold",
            minimum: 0.5,
            maximum: 100,
            step: 0.5,
            displayValueFor: { value in value.map { String(format: "%.1f %%", $0) } },
            getter: { 40 },
            setter: { _ in }
        )
    }
}
