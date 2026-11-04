import CoreLocation
import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Stands in for `Current.locationManager` so the permission card is decided by the test rather than
/// by whatever the simulator happens to have been granted.
private final class FakeLocationManager: LocationManagerProtocol {
    private let permissionState: LocationPermissionState
    private let accuracy: CLAccuracyAuthorization

    init(permissionState: LocationPermissionState, accuracy: CLAccuracyAuthorization) {
        self.permissionState = permissionState
        self.accuracy = accuracy
    }

    var currentPermissionState: LocationPermissionState { permissionState }
    var accuracyAuthorization: CLAccuracyAuthorization { accuracy }
    var isLocationServicesEnabled: Bool { true }
    func requestLocationPermission() {}
    func requestTemporaryFullAccuracyAuthorization(purposeKey: String, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
}

/// Covers the per-URL editor: the header, the address with its security level, the home network
/// section with the permission card, and the external variant.
@Suite(.sharedState)
@MainActor
struct ConnectionURLViewTests {
    private func server(
        internalURL: String,
        externalURL: String = "https://external.example.com",
        remoteUIURL: String? = nil,
        useCloud: Bool = false
    ) -> Server {
        var info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: URL(string: externalURL),
                internalURL: URL(string: internalURL),
                cloudhookURL: nil,
                remoteUIURL: remoteUIURL.flatMap(URL.init(string:)),
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: ["aa:bb:cc:dd:ee:ff"],
                isLocalPushEnabled: true,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        info.connection.useCloud = useCloud
        return Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
    }

    private func snapshot(
        urlType: ConnectionInfo.URLType,
        internalURL: String,
        externalURL: String = "https://external.example.com",
        remoteUIURL: String? = nil,
        useCloud: Bool = false,
        permission: LocationPermissionState,
        accuracy: CLAccuracyAuthorization,
        layout: SwiftUISnapshotLayout,
        testName: String = #function
    ) {
        let previousServers = Current.servers
        let previousLocationManager = Current.locationManager
        defer {
            Current.servers = previousServers
            Current.locationManager = previousLocationManager
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.locationManager = FakeLocationManager(permissionState: permission, accuracy: accuracy)

        assertLightDarkSnapshots(
            of: NavigationView {
                ConnectionURLView(
                    server: server(
                        internalURL: internalURL,
                        externalURL: externalURL,
                        remoteUIURL: remoteUIURL,
                        useCloud: useCloud
                    ),
                    urlType: urlType
                )
            },
            drawHierarchyInKeyWindow: true,
            layout: layout,
            testName: testName
        )
    }

    @Test func internalHTTPWithoutLocationPermission() async throws {
        snapshot(
            urlType: .internal,
            internalURL: "http://internal.example.com:8123",
            permission: .notDetermined,
            accuracy: .reducedAccuracy,
            layout: .fixed(width: 390, height: 1100)
        )
    }

    @Test func internalHTTPSWithLocationPermission() async throws {
        snapshot(
            urlType: .internal,
            internalURL: "https://internal.example.com:8123",
            permission: .authorizedAlways,
            accuracy: .fullAccuracy,
            layout: .fixed(width: 390, height: 900)
        )
    }

    @Test func externalWithCloud() async throws {
        snapshot(
            urlType: .external,
            internalURL: "http://internal.example.com:8123",
            remoteUIURL: "https://example.ui.nabu.casa",
            useCloud: true,
            permission: .authorizedAlways,
            accuracy: .fullAccuracy,
            layout: .fixed(width: 390, height: 600)
        )
    }

    @Test func externalPlainHTTP() async throws {
        snapshot(
            urlType: .external,
            internalURL: "http://internal.example.com:8123",
            externalURL: "http://external.example.com",
            permission: .authorizedAlways,
            accuracy: .fullAccuracy,
            layout: .fixed(width: 390, height: 700)
        )
    }

    @Test func external() async throws {
        snapshot(
            urlType: .external,
            internalURL: "http://internal.example.com:8123",
            permission: .authorizedAlways,
            accuracy: .fullAccuracy,
            layout: .fixed(width: 390, height: 600)
        )
    }

    // MARK: - Driving the editor

    /// Editing the URL lights up Save, which checks the URL (the progress shows meanwhile) and
    /// closes the editor once the check passes. The security level row only asks for its picker.
    @Test func savingAnEditedURLChecksItFirst() async throws {
        let previousServers = Current.servers
        let previousWebhooks = Current.webhooks
        let previousLocationManager = Current.locationManager
        let webhooks = HeldSendTestWebhookManager()
        defer {
            Current.servers = previousServers
            Current.webhooks = previousWebhooks
            Current.locationManager = previousLocationManager
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.webhooks = webhooks
        Current.locationManager = FakeLocationManager(permissionState: .authorizedAlways, accuracy: .fullAccuracy)
        let server = server(internalURL: "http://internal.example.com:8123")

        let driver = await SwiftUIScreenDriver.show(ConnectionURLView(server: server, urlType: .internal))
        defer { driver.close() }

        await driver.type("http://new-internal.example.com:8123")
        // Save is the only toolbar button (drawn as a checkmark, without a title).
        #expect(driver.barButtons.count == 1)
        await driver.tapBarButton(0)
        await #expect(driver.waitUntil { webhooks.pendingCheck != nil })
        await driver.settle()
        webhooks.pendingCheck?.fulfill(())
        await #expect(driver.waitUntil {
            server.info.connection.address(for: .internal)?.absoluteString == "http://new-internal.example.com:8123"
        })

        // The security level row sits under the URL field (header first, then the URL section); it
        // only raises its picker, which is put away again.
        await driver.tapRow(IndexPath(item: 1, section: 1))
        await driver.dismissPresented()
    }

    /// "Learn more" under the local push switch opens the local push documentation in the browser.
    @Test func localPushLearnMoreOpensItsDocumentation() async throws {
        let previousServers = Current.servers
        let previousLocationManager = Current.locationManager
        defer {
            Current.servers = previousServers
            Current.locationManager = previousLocationManager
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.locationManager = FakeLocationManager(permissionState: .authorizedAlways, accuracy: .fullAccuracy)
        let server = server(internalURL: "http://internal.example.com:8123")

        try await RecordingURLOpener.with { opener in
            let driver = await SwiftUIScreenDriver.show(ConnectionURLView(server: server, urlType: .internal))
            defer { driver.close() }
            // The local push section sits just above the "how it works" link.
            let localPush = driver.sectionCount - 2
            try #require(driver.rowCount(inSection: localPush) == 2)
            await driver.tapRow(IndexPath(item: 1, section: localPush))
            #expect(opener.openedURLs.map(\.url) == [AppConstants.WebURLs.companionLocalPush])
        }
    }

    /// The Home Assistant Cloud address has no header text of its own.
    @Test func rendersTheRemoteUIVariantAndThePreviews() async throws {
        let previousServers = Current.servers
        let previousLocationManager = Current.locationManager
        defer {
            Current.servers = previousServers
            Current.locationManager = previousLocationManager
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.locationManager = FakeLocationManager(permissionState: .notDetermined, accuracy: .reducedAccuracy)

        let driver = await SwiftUIScreenDriver.show(
            ConnectionURLView(server: server(internalURL: "http://internal.example.com:8123"), urlType: .remoteUI)
        )
        defer { driver.close() }
        #expect(driver.sectionCount > 1)
        _ = ConnectionURLView_Previews.previews
    }
}

/// Holds the URL check open until the test answers it.
private final class HeldSendTestWebhookManager: WebhookManager {
    private(set) var pendingCheck: Resolver<Void>?

    override func sendTest(server: Server, baseURL: URL) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()
        pendingCheck = seal
        return promise
    }
}
