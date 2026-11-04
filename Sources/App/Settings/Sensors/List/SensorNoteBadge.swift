import Shared
import SwiftUI

/// A quiet capsule under a sensor's state stating a fact about the sensor, such as that it only
/// reports while the app is open, or only with an Apple Watch.
///
/// Quiet rather than coloured: it qualifies the state above it, it isn't a warning.
struct SensorNoteBadge: View {
    let text: String
    let accessibilityLabel: String

    /// For a sensor that only reports while the app is open on screen.
    static var foregroundOnly: SensorNoteBadge {
        SensorNoteBadge(
            text: L10n.SettingsSensors.Sensors.ForegroundOnly.badge,
            accessibilityLabel: L10n.SettingsSensors.Sensors.ForegroundOnly.accessibilityLabel
        )
    }

    /// For a metric only an Apple Watch records, which reads as unavailable without one.
    static var requiresAppleWatch: SensorNoteBadge {
        SensorNoteBadge(
            text: L10n.SettingsSensors.Sensors.RequiresAppleWatch.badge,
            accessibilityLabel: L10n.SettingsSensors.Sensors.RequiresAppleWatch.accessibilityLabel
        )
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignSystem.Spaces.one)
            .padding(.vertical, DesignSystem.Spaces.micro)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    List {
        VStack(alignment: .leading) {
            Text("Camera Motion")
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text("false")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                SensorNoteBadge.foregroundOnly
            }
        }
        VStack(alignment: .leading) {
            Text("Stand Hours")
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text("10 hours")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                SensorNoteBadge.requiresAppleWatch
            }
        }
    }
}
