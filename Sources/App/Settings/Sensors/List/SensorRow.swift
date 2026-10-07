import Shared
import SwiftUI

struct SensorRow: View {
    let sensor: WebhookSensor
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            if let icon = sensor.Icon.flatMap({ MaterialDesignIcons(serversideValueNamed: $0) }) {
                Image(uiImage: icon.settingsIcon(for: UITraitCollection.current))
                    .renderingMode(.template)
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
            }
            VStack(alignment: .leading) {
                HStack(spacing: DesignSystem.Spaces.one) {
                    Text(sensor.Name ?? L10n.unknownLabel)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    // The focus name sensor is a Labs feature, so the row says so next to its name.
                    if sensor.UniqueID == WebhookSensorId.focusName.rawValue {
                        LabsLabel()
                    }
                }
                // The badge sits on the state line rather than beside the name: the state it
                // qualifies is right there, and a long sensor name keeps the full width to wrap
                // into instead of being squeezed word by word.
                HStack(spacing: DesignSystem.Spaces.one) {
                    Text(
                        isEnabled
                            ? sensor.StateDescription ?? L10n.unknownLabel
                            : L10n.SettingsSensors.disabledStateReplacement
                    )
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    // Some sensors cannot be kept current once the app leaves the screen, so the
                    // row says so rather than letting a frozen state look like a failure.
                    if SensorForegroundAvailability.isForegroundOnly(sensorUniqueID: sensor.UniqueID) {
                        SensorForegroundOnlyBadge()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
