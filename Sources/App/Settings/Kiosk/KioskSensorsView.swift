import Shared
import SwiftUI

struct KioskSensorsView: View {
    @StateObject private var viewModel = KioskSensorsViewModel()

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .motionSensorIcon,
                title: L10n.Kiosk.Sensors.title,
                subtitle: L10n.Kiosk.Sensors.body
            )

            Section {
                ForEach(viewModel.sensors, id: \.UniqueID) { sensor in
                    sensorRow(sensor)
                }
            } footer: {
                Text(L10n.Kiosk.Sensors.footer)
            }
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private func sensorRow(_ sensor: WebhookSensor) -> some View {
        let isEnabled = viewModel.isEnabled(sensor)
        return Toggle(isOn: Binding(
            get: { viewModel.isEnabled(sensor) },
            set: { viewModel.setEnabled($0, for: sensor) }
        )) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sensor.Name ?? L10n.unknownLabel)
                    if isEnabled, let state = sensor.StateDescription {
                        Text(state)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                if let icon = sensor.Icon.flatMap({ MaterialDesignIcons(serversideValueNamed: $0) }) {
                    MaterialDesignIconsImage(icon: icon, size: 24)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        KioskSensorsView()
    }
}
