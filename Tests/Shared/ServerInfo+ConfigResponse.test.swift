import Foundation
import ObjectMapper
@testable import Shared
import Testing

@Suite("ServerInfo config response")
struct ServerInfoConfigResponseTests {
    @Test("Applies what the server reports about itself")
    func appliesReportedConfig() throws {
        let config = try #require(ConfigResponse(JSON: [
            "version": "2026.9.3",
            "location_name": "Casa",
            "hass_device_id": "device-1",
            "instance_id": "instance-1",
            "cloudhook_url": "https://hooks.nabu.casa/webhook-id",
            "remote_ui_url": "https://example.ui.nabu.casa",
        ]))
        var info = ServerInfo.fake()

        info.apply(config)

        #expect(info.instanceID == "instance-1")
        #expect(info.hassDeviceId == "device-1")
        #expect(info.remoteName == "Casa")
        #expect(info.version == Version(major: 2026, minor: 9, patch: 3))
        #expect(info.connection.cloudhookURL == URL(string: "https://hooks.nabu.casa/webhook-id"))
        #expect(info.connection.address(for: .remoteUI) == URL(string: "https://example.ui.nabu.casa"))
    }

    @Test("A Home Assistant too old to report an instance ID keeps the stored one")
    func keepsStoredInstanceID() throws {
        let config = try #require(ConfigResponse(JSON: [
            "version": "2026.9.3",
            "location_name": "Casa",
        ]))
        var info = ServerInfo.fake()
        info.instanceID = "instance-1"

        info.apply(config)

        #expect(info.instanceID == "instance-1")
    }

    @Test("A server that reports no name falls back to the default one")
    func fallsBackToDefaultName() throws {
        let config = try #require(ConfigResponse(JSON: ["version": "2026.9.3"]))
        var info = ServerInfo.fake()

        info.apply(config)

        #expect(info.remoteName == ServerInfo.defaultName)
    }

    @Test("An unreadable version keeps the stored one")
    func keepsStoredVersion() throws {
        let config = try #require(ConfigResponse(JSON: ["version": "meow"]))
        var info = ServerInfo.fake()
        let storedVersion = info.version

        info.apply(config)

        #expect(info.version == storedVersion)
    }
}
