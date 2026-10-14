import CoreLocation
import Foundation
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

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
@Suite(.serialized)
@MainActor
struct ConnectionURLViewTests {
    private func server(internalURL: String) -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
                internalURL: URL(string: internalURL),
                cloudhookURL: nil,
                remoteUIURL: nil,
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
        return Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
    }

    private func snapshot(
        urlType: ConnectionInfo.URLType,
        internalURL: String,
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
                ConnectionURLView(server: server(internalURL: internalURL), urlType: urlType)
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

    @Test func external() async throws {
        snapshot(
            urlType: .external,
            internalURL: "http://internal.example.com:8123",
            permission: .authorizedAlways,
            accuracy: .fullAccuracy,
            layout: .fixed(width: 390, height: 600)
        )
    }
}
