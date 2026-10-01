@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit

/// The invitation link a server's settings screen shares.
@MainActor
struct ConnectionSettingsViewModelInvitationTests {
    @Test func invitesToTheServersExternalAddress() throws {
        let server = Server.fake()
        let viewModel = ConnectionSettingsViewModel(server: server)

        let url = try #require(viewModel.invitationURL())

        #expect(url.absoluteString.hasPrefix("https://my.home-assistant.io/invite/#url="))
        #expect(url.absoluteString.contains("homeassistant.local"))
    }

    @Test func offersNoInvitationWithoutAnAddress() {
        let server = Server.fake { info in
            info.connection.set(address: nil, for: .external)
            info.connection.set(address: nil, for: .internal)
        }
        let viewModel = ConnectionSettingsViewModel(server: server)

        #expect(viewModel.invitationURL() == nil)
    }

    /// Sharing hands the invitation link to the system share sheet, and there is nothing to share without one.
    @Test func sharesTheInvitationLink() {
        let viewModel = ConnectionSettingsViewModel(server: .fake())

        #expect(viewModel.shareServer() != nil)
    }

    @Test func sharesNothingWithoutAnAddress() {
        let server = Server.fake { info in
            info.connection.set(address: nil, for: .external)
            info.connection.set(address: nil, for: .internal)
        }

        #expect(ConnectionSettingsViewModel(server: server).shareServer() == nil)
    }
}
