import Shared
import SwiftUI

/// One server's location choice, reached from the list of servers the location screen shows when
/// the watch has more than one. The choice stops responding if a sync from the iPhone removes the
/// server while the screen is open, so nothing is recorded for a server the watch no longer has.
struct WatchServerLocationSettingsView: View {
    let server: Server

    @StateObject private var viewModel = WatchSensorsSettingsViewModel()

    var body: some View {
        List {
            WatchLocationPrivacySection(server: server)
                .disabled(!viewModel.hasServer(server.identifier))
        }
        .navigationTitle(Text(verbatim: server.info.name))
    }
}

#Preview {
    NavigationView {
        WatchServerLocationSettingsView(server: ServerFixture.standard)
    }
}
