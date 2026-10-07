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
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
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
            // A footer under the row rather than under the section: it explains this one sensor, and the
            // section holds every sleep sensor.
            if let footer = metric.footer {
                Text(footer.text)
                    .foregroundColor(.secondary)
                    .font(DesignSystem.Font.footnote)
            }
        }
    }
}

#Preview {
    List {
        HealthSensorRow(metric: .restingHeartRate, stateDescription: "62 bpm", isEnabled: .constant(true))
        HealthSensorRow(metric: .restingHeartRate, stateDescription: nil, isEnabled: .constant(false))
        if let inBed = HealthKitMetric.metric(uniqueID: "health_sleep_in_bed") {
            HealthSensorRow(metric: inBed, stateDescription: "unavailable", isEnabled: .constant(true))
        }
    }
}
#endif
