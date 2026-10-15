import Shared
import SwiftUI

struct SensorRow: View {
    let sensor: WebhookSensor
    let isEnabled: Bool
    /// Whether this device can report the sensor at all. One it never can says so instead of
    /// showing a state, and leaves out the badge about when it updates, which would suggest it does.
    var isAvailable = true

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
                // The badge sits under the state rather than beside it, so neither a long name nor
                // a long translated state has to share its width with the badge.
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(stateText)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    // Some sensors cannot be kept current once the app leaves the screen, so the
                    // row says so rather than letting a frozen state look like a failure.
                    if isAvailable, SensorForegroundAvailability.isForegroundOnly(sensorUniqueID: sensor.UniqueID) {
                        SensorForegroundOnlyBadge()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stateText: String {
        guard isAvailable else { return L10n.SettingsSensors.Sensors.UnavailableOnDevice.state }
        return isEnabled
            ? sensor.StateDescription ?? L10n.unknownLabel
            : L10n.SettingsSensors.disabledStateReplacement
    }
}
