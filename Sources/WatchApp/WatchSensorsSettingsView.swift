import SFSafeSymbols
import Shared
import SwiftUI

/// The sensors the watch reports about itself to Home Assistant, as a device of its own. They are
/// chosen per server, as on the iPhone: with one server its switches are right here, and with
/// several this screen lists the servers and the switches live one step in. The status of the last
/// report is device-wide, so it stays here either way.
struct WatchSensorsSettingsView: View {
    @StateObject private var viewModel = WatchSensorsSettingsViewModel()
    @State private var lastReportAt = WatchUserDefaults.shared.lastSensorReportAt
    @State private var lastError = WatchUserDefaults.shared.lastSensorReportError

    var body: some View {
        List {
            if viewModel.servers.isEmpty {
                Section {
                    Text(verbatim: L10n.Watch.Settings.noServers)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.servers.count == 1, let server = viewModel.servers.first {
                WatchSensorTogglesSection(server: server)
            } else {
                serversSection
            }

            statusSection
        }
        .navigationTitle(Text(verbatim: L10n.Watch.Settings.Sensors.title))
        .onAppear {
            viewModel.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchDeviceReporter.didFinishNotification)) { _ in
            lastReportAt = WatchUserDefaults.shared.lastSensorReportAt
            lastError = WatchUserDefaults.shared.lastSensorReportError
        }
    }

    /// Each server picks its own sensors, so with more than one there is nothing sensible to toggle
    /// on this screen: it lists the servers, and the switches live one step in.
    private var serversSection: some View {
        Section {
            ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                NavigationLink {
                    WatchServerSensorsSettingsView(server: server)
                } label: {
                    Label {
                        Text(verbatim: server.info.name)
                    } icon: {
                        Image(systemSymbol: .network)
                    }
                }
            }
        } footer: {
            Text(verbatim: L10n.SettingsSensors.Servers.footer)
        }
    }

    private var statusSection: some View {
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
}

#Preview {
    NavigationView {
        WatchSensorsSettingsView()
    }
}
