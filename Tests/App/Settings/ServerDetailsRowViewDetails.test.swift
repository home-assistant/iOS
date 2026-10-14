import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers the detail rows built straight from a `Server` for the servers list's long-press preview.
@Suite(.serialized)
@MainActor
struct ServerDetailsRowViewDetailsTests {
    private func makeServer(
        internalURL: String?,
        externalURL: String?,
        remoteUIURL: String? = nil,
        useCloud: Bool = false,
        deviceName: String? = nil
    ) -> Server {
        var info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL.flatMap(URL.init(string:)),
                internalURL: internalURL.flatMap(URL.init(string:)),
                cloudhookURL: nil,
                remoteUIURL: remoteUIURL.flatMap(URL.init(string:)),
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .lessSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        info.connection.useCloud = useCloud
        info.setSetting(value: deviceName, for: .overrideDeviceName)
        return Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
    }

    @Test func rowsMirrorTheServer() {
        let details = ServerDetailsRowView.details(for: makeServer(
            internalURL: "http://internal.example.com:8123",
            externalURL: "https://external.example.com",
            deviceName: "My Phone"
        ))

        #expect(details.map(\.option) == [.deviceName, .internalURL, .externalURL])
        #expect(details[0].value == "My Phone")
        #expect(!details[0].isPlaceholder)
        #expect(details[1].value == "http://internal.example.com:8123")
        #expect(!details[1].isActive)
        #expect(details[2].value == "https://external.example.com")
        #expect(details[2].isActive)
    }

    @Test func internalURLIsActiveWhenItIsTheOnlyOne() {
        let details = ServerDetailsRowView.details(for: makeServer(
            internalURL: "http://internal.example.com:8123",
            externalURL: nil
        ))

        #expect(details[1].isActive)
        #expect(!details[2].isActive)
    }

    @Test func missingValuesBecomePlaceholders() {
        let details = ServerDetailsRowView.details(for: makeServer(internalURL: nil, externalURL: nil))

        #expect(details[0].isPlaceholder)
        #expect(details[1].value == nil)
        #expect(!details[1].isActive)
        #expect(details[2].value == nil)
        #expect(!details[2].isActive)
    }

    @Test func cloudShowsAsTheExternalURL() {
        let details = ServerDetailsRowView.details(for: makeServer(
            internalURL: nil,
            externalURL: nil,
            remoteUIURL: "https://example.ui.nabu.casa",
            useCloud: true
        ))

        #expect(details[2].value == L10n.Settings.ConnectionSection.HomeAssistantCloud.title)
        #expect(details[2].isActive)
        #expect(details[2].symbol == .icloud)
    }
}
