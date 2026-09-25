import Shared
import SwiftUI

/// One server's copy of the sensors screen, reached from the list of servers the root screen shows
/// when the watch has more than one. Sensors are chosen per server, so the switches here belong to
/// this server alone.
struct WatchServerSensorsSettingsView: View {
    let server: Server

    var body: some View {
        List {
            WatchSensorTogglesSection(server: server)
        }
        .navigationTitle(Text(verbatim: server.info.name))
    }
}

#Preview {
    NavigationView {
        WatchServerSensorsSettingsView(server: ServerFixture.standard)
    }
}
