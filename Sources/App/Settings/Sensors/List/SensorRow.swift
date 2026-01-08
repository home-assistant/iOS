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
                Text(sensor.Name ?? L10n.unknownLabel)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                if isEnabled {
                    Text(sensor.StateDescription ?? L10n.unknownLabel)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    Text(L10n.SettingsSensors.disabledStateReplacement)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
