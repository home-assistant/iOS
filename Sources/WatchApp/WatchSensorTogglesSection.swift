import Shared
import SwiftUI

/// The switches for what one server receives of the watch's own sensors. Every sensor is opt-in:
/// nothing is sent to the server until its switch is on. Flipping one records the choice for this
/// server alone and sends the current values straight away.
struct WatchSensorTogglesSection: View {
    let server: Server

    @State private var enabledIDs: Set<String>

    init(server: Server) {
        self.server = server
        self._enabledIDs = State(initialValue: WatchUserDefaults.shared.enabledSensorIDs(forServer: server.identifier))
    }

    var body: some View {
        Section {
            ForEach(WatchDeviceSensors.all) { sensor in
                Toggle(isOn: Binding(
                    get: { enabledIDs.contains(sensor.uniqueID) },
                    set: { enabled in
                        if enabled {
                            enabledIDs.insert(sensor.uniqueID)
                        } else {
                            enabledIDs.remove(sensor.uniqueID)
                        }
                        WatchUserDefaults.shared.setSensorEnabled(
                            enabled,
                            uniqueID: sensor.uniqueID,
                            forServer: server.identifier
                        )
                        Task {
                            await WatchDeviceReporter.shared.report(trigger: .settingsChange)
                        }
                    }
                )) {
                    Text(verbatim: sensor.name)
                }
            }
        } footer: {
            Text(verbatim: L10n.Watch.Settings.Sensors.footer)
        }
    }
}

#Preview {
    NavigationView {
        List {
            WatchSensorTogglesSection(server: ServerFixture.standard)
        }
    }
}
