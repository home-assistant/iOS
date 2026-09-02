import Shared
import SwiftUI

/// The sensors the watch reports about itself to Home Assistant, as a device of its own. Every
/// sensor is opt-in: nothing is sent until its switch is on. Flipping one registers the change
/// with every server and sends the current value straight away.
struct WatchSensorsSettingsView: View {
    @State private var enabledIDs = WatchUserDefaults.shared.enabledSensorIDs
    @State private var lastReportAt = WatchUserDefaults.shared.lastSensorReportAt
    @State private var lastError = WatchUserDefaults.shared.lastSensorReportError

    var body: some View {
        List {
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
                            WatchUserDefaults.shared.setSensorEnabled(enabled, uniqueID: sensor.uniqueID)
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

            Section {
                if let lastReportAt {
                    Text(verbatim: L10n.Watch.Settings.Sensors.lastSent(
                        lastReportAt.formatted(date: .abbreviated, time: .shortened)
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Text(verbatim: L10n.Watch.Settings.Sensors.neverSent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let lastError, !lastError.isEmpty {
                    Text(verbatim: L10n.Watch.Settings.Sensors.lastError(lastError))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text(verbatim: L10n.Watch.Settings.Sensors.statusHeader)
            }
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Sensors.title))
        .onReceive(NotificationCenter.default.publisher(for: WatchDeviceReporter.didFinishNotification)) { _ in
            lastReportAt = WatchUserDefaults.shared.lastSensorReportAt
            lastError = WatchUserDefaults.shared.lastSensorReportError
        }
    }
}

#Preview {
    NavigationView {
        WatchSensorsSettingsView()
    }
}
