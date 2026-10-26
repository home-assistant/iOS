import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

struct ServerIdentityConflictingServerTests {
    @Test func prefersTheInternalAddress() {
        let info = with(ServerInfo.fake()) {
            $0.remoteName = "Home"
            $0.connection.set(address: URL(string: "http://homeassistant.local:8123/"), for: .internal)
            $0.connection.set(address: URL(string: "https://home.example.com"), for: .external)
        }

        let server = ServerIdentityConflictingServer(info: info)

        #expect(server.name == "Home")
        #expect(server.address == "http://homeassistant.local:8123")
        #expect(server.id == "Home|http://homeassistant.local:8123")
    }

    @Test func fallsBackToTheExternalAddress() {
        let info = with(ServerInfo.fake()) {
            $0.connection.set(address: nil, for: .internal)
            $0.connection.set(address: URL(string: "https://home.example.com"), for: .external)
        }

        #expect(ServerIdentityConflictingServer(info: info).address == "https://home.example.com")
    }

    @Test func hasNoAddressWithoutAURL() {
        let info = with(ServerInfo.fake()) {
            $0.connection.set(address: nil, for: .internal)
            $0.connection.set(address: nil, for: .external)
        }

        let server = ServerIdentityConflictingServer(info: info)

        #expect(server.address == nil)
        #expect(server.id == "\(server.name)|")
    }
}
