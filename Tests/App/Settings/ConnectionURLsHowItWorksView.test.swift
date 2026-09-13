import CoreLocation
import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

/// Stands in for `Current.locationManager` so the requirements list is decided by the test rather
/// than by whatever the simulator happens to have been granted.
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
}

private func makeServer(
    internalURL: URL?,
    externalURL: URL?,
    internalSSIDs: [String]?,
    securityLevel: ConnectionSecurityLevel = .undefined
) -> Server {
    let info = ServerInfo(
        name: "Test Server",
        connection: .init(
            externalURL: externalURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook-id",
            webhookSecret: nil,
            internalSSIDs: internalSSIDs,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: securityLevel
        ),
        token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
        version: "2024.1"
    )
    return Server.fake(identifier: .init(rawValue: "test-server"), initial: info)
}

/// Pins everything the screen reads from the environment: the granted location permission and the
/// network the device is on, through both the cached and the freshly fetched accessors.
private func withEnvironment(
    permissionState: LocationPermissionState,
    accuracy: CLAccuracyAuthorization,
    networkState: NetworkState,
    _ body: () -> Void
) {
    let previousLocationManager = Current.locationManager
    let previousCurrent = Current.connectivity.currentNetworkState
    let previousLastKnown = Current.connectivity.lastKnownNetworkState
    let previousRefresh = Current.connectivity.refreshNetworkInformation
    defer {
        Current.locationManager = previousLocationManager
        Current.connectivity.currentNetworkState = previousCurrent
        Current.connectivity.lastKnownNetworkState = previousLastKnown
        Current.connectivity.refreshNetworkInformation = previousRefresh
    }

    Current.locationManager = FakeLocationManager(permissionState: permissionState, accuracy: accuracy)
    Current.connectivity.currentNetworkState = { networkState }
    Current.connectivity.lastKnownNetworkState = { networkState }
    Current.connectivity.refreshNetworkInformation = {}

    body()
}

@Suite(.serialized)
@MainActor
struct ConnectionURLsHowItWorksViewTests {
    @Test func everyRequirementMet() async throws {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            internalSSIDs: ["MyWifi"]
        )

        withEnvironment(
            permissionState: .authorizedAlways,
            accuracy: .fullAccuracy,
            networkState: .init(ssid: "MyWifi")
        ) {
            assertLightDarkSnapshots(
                of: NavigationView { ConnectionURLsHowItWorksView(server: server) },
                drawHierarchyInKeyWindow: true,
                // Taller than a device so the requirements and the URL in use are captured too,
                // rather than only what fits above the fold.
                layout: .fixed(width: 390, height: 2200)
            )
        }
    }

    @Test func requirementsMissing() async throws {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            internalSSIDs: nil,
            securityLevel: .mostSecure
        )

        withEnvironment(
            permissionState: .authorizedWhenInUse,
            accuracy: .reducedAccuracy,
            networkState: .init(ssid: "SomeCafe")
        ) {
            assertLightDarkSnapshots(
                of: NavigationView { ConnectionURLsHowItWorksView(server: server) },
                drawHierarchyInKeyWindow: true,
                // Taller than a device so the requirements and the URL in use are captured too,
                // rather than only what fits above the fold.
                layout: .fixed(width: 390, height: 2200)
            )
        }
    }

    @Test func internalURLScreenAsksForPermissionAndAccuracy() async throws {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            internalSSIDs: ["MyWifi"]
        )

        withEnvironment(
            permissionState: .authorizedWhenInUse,
            accuracy: .reducedAccuracy,
            networkState: .init(ssid: "MyWifi")
        ) {
            assertLightDarkSnapshots(
                of: NavigationView { ConnectionURLView(server: server, urlType: .internal) },
                drawHierarchyInKeyWindow: true,
                layout: .fixed(width: 390, height: 1400)
            )
        }
    }
}

@Suite(.serialized)
@MainActor
struct ConnectionURLsHowItWorksViewModelTests {
    @Test func marksEveryRequirementMetOnAListedNetwork() {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            internalSSIDs: ["MyWifi"]
        )

        withEnvironment(
            permissionState: .authorizedAlways,
            accuracy: .fullAccuracy,
            networkState: .init(ssid: "MyWifi")
        ) {
            let viewModel = ConnectionURLsHowItWorksViewModel(server: server)
            #expect(viewModel.requirements.filter { !$0.isMet }.isEmpty)
            #expect(viewModel.activeURLType == .internal)
            #expect(viewModel.activeURL?.absoluteString == "http://internal.example.com:8123")
        }
    }

    @Test func reducedAccuracyAndWhenInUseAreReportedSeparately() {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            internalSSIDs: ["MyWifi"]
        )

        withEnvironment(
            permissionState: .authorizedWhenInUse,
            accuracy: .reducedAccuracy,
            networkState: .init(ssid: "MyWifi")
        ) {
            let viewModel = ConnectionURLsHowItWorksViewModel(server: server)
            let met = Dictionary(
                uniqueKeysWithValues: viewModel.requirements.map { ($0.kind, $0.isMet) }
            )
            #expect(met[.preciseLocation] == false)
            #expect(met[.alwaysLocation] == false)
            #expect(met[.internalURL] == true)
            #expect(met[.listedNetworks] == true)
        }
    }

    @Test func reportsTheServersConnectionSecurityLevel() {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: nil,
            internalSSIDs: ["MyWifi"],
            securityLevel: .mostSecure
        )

        withEnvironment(
            permissionState: .authorizedAlways,
            accuracy: .fullAccuracy,
            networkState: .init(ssid: "SomeCafe")
        ) {
            let viewModel = ConnectionURLsHowItWorksViewModel(server: server)
            #expect(viewModel.securityLevel == .mostSecure)
            // Most secure keeps a plain-HTTP internal URL unused away from a listed network, and
            // this server has nothing else to fall back to.
            #expect(viewModel.activeURLType == ConnectionInfo.URLType.none)
            #expect(viewModel.activeURL == nil)
        }
    }

    @Test func fallsBackToTheExternalURLAwayFromAListedNetwork() {
        let server = makeServer(
            internalURL: URL(string: "http://internal.example.com:8123"),
            externalURL: URL(string: "https://external.example.com"),
            internalSSIDs: ["MyWifi"]
        )

        withEnvironment(
            permissionState: .authorizedAlways,
            accuracy: .fullAccuracy,
            networkState: .init(ssid: "SomeCafe")
        ) {
            let viewModel = ConnectionURLsHowItWorksViewModel(server: server)
            let onListedNetwork = viewModel.requirements.first { $0.kind == .onListedNetwork }
            #expect(onListedNetwork?.isMet == false)
            #expect(viewModel.activeURLType == .external)
            #expect(viewModel.activeURL?.absoluteString == "https://external.example.com")
        }
    }
}
