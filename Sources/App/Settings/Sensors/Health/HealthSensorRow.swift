#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

struct HealthSensorRow: View {
    let metric: HealthKitMetric
    @Binding var isEnabled: Bool

    private var icon: UIImage {
        MaterialDesignIcons(serversideValueNamed: metric.icon)
            .settingsIcon(for: UITraitCollection.current)
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
                    if let unit = metric.unit {
                        Text(unit)
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
        HealthSensorRow(metric: .steps, isEnabled: .constant(true))
        HealthSensorRow(metric: .restingHeartRate, isEnabled: .constant(false))
    }
}
#endif
