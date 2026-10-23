import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Covers the webhook screen of a server reached through Home Assistant Link, whose footer explains
/// that the cloudhook is used away from home.
@Suite(.serialized)
@MainActor
struct WebhookDetailViewTests {
    @Test func webhookDetailWithHomeAssistantLinkCloudhook() async throws {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: nil,
                internalURL: URL(string: "http://internal.example.com:8123"),
                cloudhookURL: URL(string: "https://hooks.nabu.casa/cloudhook-id"),
                remoteUIURL: URL(string: "https://remote.ui.nabu.casa"),
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .undefined
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        let server = Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
        let state = NetworkState(ssid: "SomeCafe")

        let previousCurrent = Current.connectivity.currentNetworkState
        let previousLastKnown = Current.connectivity.lastKnownNetworkState
        let previousRefresh = Current.connectivity.refreshNetworkInformation
        defer {
            Current.connectivity.currentNetworkState = previousCurrent
            Current.connectivity.lastKnownNetworkState = previousLastKnown
            Current.connectivity.refreshNetworkInformation = previousRefresh
        }
        Current.connectivity.currentNetworkState = { state }
        Current.connectivity.lastKnownNetworkState = { state }
        Current.connectivity.refreshNetworkInformation = {}

        assertLightDarkSnapshots(
            of: NavigationView { WebhookDetailView(server: server) },
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: 390, height: 1400)
        )
    }
}
