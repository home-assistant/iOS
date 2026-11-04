import CoreLocation
import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Covers the per-server connection screen, whose details section now carries the
/// "Understand Internal vs External URLs" row under the two URL rows.
@Suite(.sharedState)
@MainActor
struct ConnectionSettingsViewTests {
    @Test func serverConnectionScreen() async throws {
        try await assertServerConnectionScreen()
    }

    @Test func settingsSearchFindsReauthenticate() {
        #expect(ConnectionSettingsView.settingsSearchEntries.contains { $0.matches(searchQuery: "re-auth") })
    }

    /// Open hands the server to the coordinator; outside a window's Settings sheet that is the app-wide one.
    @Test func openingTheServerActivatesIt() async {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)
        let server = Server.fake()
        let coordinator = MockAppCoordinator()
        Current.sceneManager.registerAppCoordinator(coordinator)

        await withCheckedContinuation { continuation in
            coordinator.onActivateServer = { continuation.resume() }
            ConnectionSettingsView(server: server).openServer()
        }

        #expect(coordinator.activatedServers.map(\.identifier) == [server.identifier])
    }

    /// While a Re-authenticate runs, its row shows progress instead of the button title.
    @Test func serverConnectionScreenWhileReauthenticating() async throws {
        let reauthentication = ServerReauthenticationModel()
        // The sign in stays on its first step, so the row stays busy without presenting anything.
        reauthentication.reauthenticator.clientCertificateRequirement = { _ in Promise<Bool>.pending().promise }
        try await assertServerConnectionScreen(reauthentication: reauthentication) { server in
            reauthentication.reauthenticate(server, using: .external)
        }
    }

    private func assertServerConnectionScreen(
        reauthentication: ServerReauthenticationModel? = nil,
        prepare: (Server) -> Void = { _ in },
        testName: String = #function
    ) async throws {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
                internalURL: URL(string: "http://internal.example.com:8123"),
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: ["MyWifi"],
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        let server = Server.fake(identifier: .init(rawValue: "test-server"), initial: info)

        let previousServers = Current.servers
        let previousDeviceName = Current.device.deviceName
        defer {
            Current.servers = previousServers
            Current.device.deviceName = previousDeviceName
        }
        Current.servers = FakeServerManager(initial: 0)
        // The Device Name row falls back to this device's name, which differs per machine.
        Current.device.deviceName = { "iPhone" }

        prepare(server)

        assertLightDarkSnapshots(
            of: NavigationView { ConnectionSettingsView(server: server, reauthentication: reauthentication) },
            drawHierarchyInKeyWindow: true,
            // Taller than a device so the whole details section is captured, not only the part
            // that fits above the fold.
            layout: .fixed(width: 390, height: 2600),
            testName: testName
        )
    }

    @Test func searchFindsRegisteringAsANewDevice() {
        let titles = ConnectionSettingsView.settingsSearchEntries.map(\.title)
        #expect(titles.contains(L10n.Settings.ConnectionSection.RegisterAsNewDevice.title))
    }

    // MARK: - Driving the screen

    private enum Sections {
        static let privacy = 2
        static let status = 3
        static let delete = 6
    }

    private func makeServer(locked: Bool, withURL: Bool) -> Server {
        let info = ServerInfo(
            name: "Driven Server",
            connection: .init(
                externalURL: withURL ? URL(string: "https://external.example.com") : nil,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: locked ? "2021.1" : "2024.1"
        )
        return Server.fake(identifier: .init(rawValue: "driven-\(UUID().uuidString)"), initial: info)
    }

    /// Picking a privacy option stores it and closes the picker. A core too old for optional GPS
    /// keeps the location choice locked and explains why.
    @Test(arguments: [false, true])
    func privacyPickersStoreTheChoice(locked: Bool) async throws {
        let previousServers = Current.servers
        let previousRunner = Current.backgroundTask
        defer {
            Current.servers = previousServers
            Current.backgroundTask = previousRunner
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.backgroundTask = OutOfTimeBackgroundTaskRunner()
        let server = makeServer(locked: locked, withURL: false)

        let driver = await SwiftUIScreenDriver.show(ConnectionSettingsView(server: server))
        defer { driver.close() }

        try await #require(driver.push(IndexPath(item: 0, section: Sections.privacy)))
        #expect(driver.rows.count == ServerLocationPrivacy.allCases.count)
        await driver.tapRow(IndexPath(item: 1, section: 0))
        if locked {
            await driver.pop()
        } else {
            await #expect(driver.waitUntil { driver.depth == 1 })
            #expect(server.info.setting(for: .locationPrivacy) == ServerLocationPrivacy.zoneOnly)
        }

        try await #require(driver.push(IndexPath(item: 1, section: Sections.privacy)))
        await driver.tapRow(IndexPath(item: 1, section: 0))
        await #expect(driver.waitUntil { driver.depth == 1 })
        #expect(server.info.setting(for: .sensorPrivacy) == ServerSensorPrivacy.none)
    }

    /// The websocket row reads each connection state; tapping it or Delete only raises a prompt, and
    /// a server another device registered offers to replace that device.
    @Test func statusRowsFollowTheConnection() async throws {
        let previousServers = Current.servers
        let prefs = Current.settingsStore.prefs
        let previousVendorID = Current.device.identifierForVendor
        let keys = [
            SettingsStore.integrationDeviceIDKey,
            SettingsStore.integrationDeviceIDOwnerKey,
            SettingsStore.registrationRecordsKey,
            RegistrationOwnership.earlierRegistrationsAdoptedKey,
        ]
        let previousValues = keys.map { prefs.object(forKey: $0) }
        let servers = FakeServerManager(initial: 0)
        Current.servers = servers
        let server = servers.add(identifier: .init(rawValue: "connected-\(UUID().uuidString)"), serverInfo: .fake())
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        defer {
            connection.pendingRequests.removeAll()
            connection.pendingSubscriptions.removeAll()
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previousServers
            Current.device.identifierForVendor = previousVendorID
            for (key, value) in zip(keys, previousValues) {
                prefs.set(value, forKey: key)
            }
        }
        Current.device.identifierForVendor = { "this-device" }
        prefs.set(true, forKey: RegistrationOwnership.earlierRegistrationsAdoptedKey)
        Current.settingsStore.setRegistrationRecord(
            RegistrationRecord(current: RegistrationIdentity(
                deviceID: Current.settingsStore.integrationDeviceID,
                ownerVendorID: "other-device"
            )),
            for: server.identifier
        )

        let driver = await SwiftUIScreenDriver.show(ConnectionSettingsView(server: server))
        defer { driver.close() }

        let states: [HAConnectionState] = [
            .authenticating,
            .ready(version: "2024.1"),
            .disconnected(reason: .waitingToReconnect(
                lastError: URLError(.timedOut),
                atLatest: Date(),
                retryCount: 2
            )),
            .disconnected(reason: .rejected),
            .connecting,
        ]
        for state in states {
            connection.setState(state, waitForQueue: false)
            await driver.settle()
        }
        await driver.tapRow(IndexPath(item: 0, section: Sections.status))
        await driver.dismissPresented()
        await driver.tapRow(IndexPath(item: 0, section: Sections.delete))
        await driver.dismissPresented()
        // Registering anew and replacing the other device share the registration section.
        #expect(driver.rowCount(inSection: Sections.delete - 1) == 2)
    }

    /// Share hands the invitation link to a share sheet, recorded on the window's root.
    @Test func shareOffersTheInvitationLink() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)
        let server = makeServer(locked: false, withURL: true)
        defer { Current.resetAPICache(for: [server.identifier]) }

        let screen = await RecordingScreen.show(NavigationStack { ConnectionSettingsView(server: server) })
        defer { screen.close() }

        let shared = await screen.waitUntil(timeout: 5) {
            for item in screen.barButtons where item.menu == nil {
                if let action = item.action {
                    UIApplication.shared.sendAction(action, to: item.target, from: item, for: nil)
                }
            }
            return !screen.presented(UIActivityViewController.self).isEmpty
        }
        #expect(shared)
    }
}

/// Fails every background task at once, without running the work it wraps, so a privacy change
/// does not send a location update.
private final class OutOfTimeBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        Promise(error: BackgroundTaskError.outOfTime)
    }
}
