import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@MainActor
@Suite(.serialized)
struct SendspinServerOptionTests {
    @Test func readsTheServerNameAndHomeNetwork() {
        let server = Server.fake(identifier: "home") { $0.remoteName = "Home" }
        #expect(SendspinServerOption(server: server) == SendspinServerOption(
            id: "home",
            name: "Home",
            hasHomeNetwork: true
        ))

        let withoutHomeNetwork = Server.fake(identifier: "cabin") {
            $0.connection.internalSSIDs = nil
            $0.connection.internalHardwareAddresses = []
        }
        #expect(!SendspinServerOption(server: withoutHomeNetwork).hasHomeNetwork)
    }

    @Test func isOnTheHomeNetworkOnlyOfServersItIsTurnedOnFor() async {
        let previousServers = Current.servers
        let previousNetworkState = Current.connectivity.currentNetworkState
        defer {
            Current.servers = previousServers
            Current.connectivity.currentNetworkState = previousNetworkState
        }
        let servers = FakeServerManager()
        Current.servers = servers
        let home = servers.addFake()
        home.update { $0.connection.internalSSIDs = ["HomeWifi"] }
        let cabin = servers.addFake()
        cabin.update { $0.connection.internalSSIDs = ["CabinWifi"] }
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "CabinWifi") }

        let onlyHome = SendspinPlayerConfiguration(enabledServerIdentifiers: [home.identifier.rawValue])
        let isOnHomeNetworkOfHome = await SendspinPlayerController.isOnHomeNetworkOfEnabledServer(onlyHome)
        #expect(!isOnHomeNetworkOfHome)

        let both = SendspinPlayerConfiguration(enabledServerIdentifiers: [
            home.identifier.rawValue,
            cabin.identifier.rawValue,
        ])
        let isOnHomeNetworkOfEither = await SendspinPlayerController.isOnHomeNetworkOfEnabledServer(both)
        #expect(isOnHomeNetworkOfEither)
    }
}
