import Shared
import SwiftUI

/// One server's copy of the sensors screen, reached from the list of servers the root screen shows
/// when the watch has more than one. Sensors are chosen per server, so the switches here belong to
/// this server alone. They stop responding if a sync from the iPhone removes the server while the
/// screen is open, so no choice is recorded for a server the watch no longer has.
struct WatchServerSensorsSettingsView: View {
    let server: Server

    @StateObject private var viewModel = WatchSensorsSettingsViewModel()

    var body: some View {
        List {
            WatchSensorTogglesSection(server: server)
                .disabled(!viewModel.hasServer(server.identifier))
        }
        .navigationTitle(Text(verbatim: server.info.name))
    }
}

#Preview {
    NavigationView {
        WatchServerSensorsSettingsView(server: ServerFixture.standard)
    }
}
