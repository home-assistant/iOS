import Shared
import SwiftUI

/// Marks a sensor row whose sensor only reports while the app is open on screen.
///
/// A quiet capsule rather than a coloured one: this is a fact about the sensor, not a warning. It
/// sits beside the sensor's state, which is what it qualifies.
struct SensorForegroundOnlyBadge: View {
    var body: some View {
        Text(L10n.SettingsSensors.Sensors.ForegroundOnly.badge)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignSystem.Spaces.one)
            .padding(.vertical, DesignSystem.Spaces.micro)
            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            // Keeps its shape next to a state description that wants the width.
            .fixedSize()
            .accessibilityLabel(L10n.SettingsSensors.Sensors.ForegroundOnly.accessibilityLabel)
    }
}

#Preview {
    List {
        VStack(alignment: .leading) {
            Text("Camera Motion")
            HStack(spacing: DesignSystem.Spaces.one) {
                Text("false")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                SensorForegroundOnlyBadge()
            }
        }
    }
}
