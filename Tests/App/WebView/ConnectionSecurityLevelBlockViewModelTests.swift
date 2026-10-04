import Combine
import CoreLocation
@testable import HomeAssistant
import SFSafeSymbols
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// What the "most secure" connection block asks of the user before the frontend can load: a home
/// network to be set, being on it, and location access to tell.
@MainActor
final class ConnectionSecurityLevelBlockViewModelTests: XCTestCase {
    private final class FakeLocationManager: LocationManagerProtocol {
        var permissionState: LocationPermissionState

        init(permissionState: LocationPermissionState) {
            self.permissionState = permissionState
        }

        var currentPermissionState: LocationPermissionState { permissionState }
        var accuracyAuthorization: CLAccuracyAuthorization { .fullAccuracy }
        var isLocationServicesEnabled: Bool { true }
        func requestLocationPermission() {}
        func requestTemporaryFullAccuracyAuthorization(purposeKey: String, completion: @escaping (Error?) -> Void) {
            completion(nil)
        }
    }

    private var previousLocationManager: LocationManagerProtocol!
    private var previousCurrentNetworkState: (() async -> NetworkState)!
    private var locationManager: FakeLocationManager!

    override func setUp() async throws {
        previousLocationManager = Current.locationManager
        previousCurrentNetworkState = Current.connectivity.currentNetworkState
        locationManager = FakeLocationManager(permissionState: .authorizedAlways)
        Current.locationManager = locationManager
    }

    override func tearDown() async throws {
        Current.locationManager = previousLocationManager
        Current.connectivity.currentNetworkState = previousCurrentNetworkState
        locationManager = nil
    }

    // MARK: - Helpers

    private func setNetwork(ssid: String?) {
        let networkState = NetworkState(ssid: ssid)
        Current.connectivity.currentNetworkState = { networkState }
    }

    private func requirements(for server: Server) async -> [ConnectionSecurityLevelBlockViewModel.Requirement] {
        let viewModel = ConnectionSecurityLevelBlockViewModel(server: server)
        let loaded = expectation(description: "requirements loaded")
        let subscription = viewModel.$requirements.dropFirst().sink { _ in loaded.fulfill() }
        viewModel.loadRequirements()
        await fulfillment(of: [loaded], timeout: 5)
        subscription.cancel()
        return viewModel.requirements
    }

    private func serverWithoutHomeNetwork() -> Server {
        Server.fake(update: { info in
            info.connection.internalSSIDs = nil
            info.connection.internalHardwareAddresses = nil
        })
    }

    // MARK: - Tests

    func testMissingHomeNetworkIsRequired() async {
        let requirements = await requirements(for: serverWithoutHomeNetwork())

        XCTAssertEqual(requirements, [.homeNetworkMissing])
    }

    func testBeingAwayFromTheHomeNetworkIsReported() async {
        setNetwork(ssid: "Elsewhere")

        let requirements = await requirements(for: Server.fake())

        XCTAssertEqual(requirements, [.notOnHomeNetwork])
    }

    func testNothingIsRequiredOnTheHomeNetworkWithLocationAccess() async {
        setNetwork(ssid: "MyWifi")
        locationManager.permissionState = .authorizedWhenInUse

        let requirements = await requirements(for: Server.fake())

        XCTAssertEqual(requirements, [])
    }

    func testMissingLocationAccessIsRequired() async {
        setNetwork(ssid: "MyWifi")
        locationManager.permissionState = .denied

        let requirements = await requirements(for: Server.fake())

        XCTAssertEqual(requirements, [.locationPermission])
    }

    func testRequirementsHaveTitlesAndSymbols() {
        typealias Requirement = ConnectionSecurityLevelBlockViewModel.Requirement

        XCTAssertEqual(
            Requirement.homeNetworkMissing.title,
            L10n.ConnectionSecurityLevelBlock.Requirement.HomeNetworkMissing.title
        )
        XCTAssertEqual(
            Requirement.notOnHomeNetwork.title,
            L10n.ConnectionSecurityLevelBlock.Requirement.NotOnHomeNetwork.title
        )
        XCTAssertEqual(
            Requirement.locationPermission.title,
            L10n.ConnectionSecurityLevelBlock.Requirement.LocationPermissionMissing.title
        )
        XCTAssertEqual(Requirement.homeNetworkMissing.systemSymbol, .wifi)
        XCTAssertEqual(Requirement.notOnHomeNetwork.systemSymbol, .wifiSlash)
        XCTAssertEqual(Requirement.locationPermission.systemSymbol, .location)
    }

    /// Lays the block screen out in each state so SwiftUI evaluates its body.
    func testBlockScreenLaysOutWithAndWithoutRequirements() {
        setNetwork(ssid: "MyWifi")
        for (permission, server) in [
            (LocationPermissionState.authorizedAlways, Server.fake()),
            (.denied, serverWithoutHomeNetwork()),
        ] {
            locationManager.permissionState = permission
            let controller = UIHostingController(rootView: ConnectionSecurityLevelBlockView(server: server))
            // On the host app's scene, so the window really appears and `onAppear` runs.
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller
            window.isHidden = false
            controller.view.layoutIfNeeded()
            // Lets the requirements loaded on appear come back and lays the screen out again with them.
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
            controller.view.layoutIfNeeded()

            XCTAssertGreaterThan(controller.view.bounds.height, 0)
            window.isHidden = true
            window.rootViewController = nil
        }
    }
}
