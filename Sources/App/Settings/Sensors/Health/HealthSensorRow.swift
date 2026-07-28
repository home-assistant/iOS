#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

struct HealthSensorRow: View {
    let metric: HealthKitMetric
    /// Latest reported value, when there is one. Falls back to the unit so the row still says what the
    /// sensor would report once it's enabled.
    let stateDescription: String?
    @Binding var isEnabled: Bool

    private var icon: UIImage {
        MaterialDesignIcons(serversideValueNamed: metric.icon)
            .settingsIcon(for: UITraitCollection.current)
    }

    private var subtitle: String? {
        guard isEnabled else { return L10n.SettingsSensors.disabledStateReplacement }
        return stateDescription ?? metric.unit
    }

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: DesignSystem.Spaces.two) {
                Image(uiImage: icon)
                    .renderingMode(.template)
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                VStack(alignment: .leading) {
                    Text(metric.name)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    if let subtitle {
                        Text(subtitle)
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

#Preview {
    List {
        HealthSensorRow(metric: .restingHeartRate, stateDescription: "62 bpm", isEnabled: .constant(true))
        HealthSensorRow(metric: .restingHeartRate, stateDescription: nil, isEnabled: .constant(false))
    }
}
#endif
