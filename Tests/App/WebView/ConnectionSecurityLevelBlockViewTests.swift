import Combine
import CoreLocation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The screen that blocks the frontend while the most secure connection level can't be met: which
/// requirements it lists for a server, and that it renders with and without them.
@Suite(.sharedState)
@MainActor
struct ConnectionSecurityLevelBlockViewTests {
    private final class FakeLocationManager: LocationManagerProtocol {
        let permissionState: LocationPermissionState

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

    private func withLocationPermission(
        _ state: LocationPermissionState,
        _ body: () async throws -> Void
    ) async rethrows {
        let previous = Current.locationManager
        Current.locationManager = FakeLocationManager(permissionState: state)
        defer { Current.locationManager = previous }
        try await body()
    }

    private func server(ssids: [String]?, hardwareAddresses: [String]? = nil) -> Server {
        Server.fake { info in
            info.connection.internalSSIDs = ssids
            info.connection.internalHardwareAddresses = hardwareAddresses
        }
    }

    private func requirements(for server: Server) async -> [ConnectionSecurityLevelBlockViewModel.Requirement] {
        let viewModel = ConnectionSecurityLevelBlockViewModel(server: server)
        var loaded: [ConnectionSecurityLevelBlockViewModel.Requirement]?
        let cancellable = viewModel.$requirements.dropFirst().sink { loaded = $0 }
        defer { cancellable.cancel() }
        viewModel.loadRequirements()
        let deadline = Date().addingTimeInterval(10)
        while loaded == nil, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return loaded ?? []
    }

    @Test func requirementsDescribeThemselves() {
        let all: [ConnectionSecurityLevelBlockViewModel.Requirement] = [
            .homeNetworkMissing,
            .notOnHomeNetwork,
            .locationPermission,
        ]
        #expect(Set(all.map(\.title)).count == 3)
        #expect(all.map(\.systemSymbol) == [.wifi, .wifiSlash, .location])
    }

    @Test func aServerWithoutAHomeNetworkAsksForOneAndForLocation() async {
        await withLocationPermission(.denied) {
            let result = await requirements(for: server(ssids: nil))
            #expect(result == [.homeNetworkMissing, .locationPermission])
        }
    }

    @Test func aServerWithAHomeNetworkAsksToJoinIt() async {
        await withLocationPermission(.authorizedAlways) {
            let result = await requirements(for: server(ssids: ["Not The Simulator Network"]))
            #expect(result == [.notOnHomeNetwork])
        }
    }

    @Test func aHardwareAddressAloneCountsAsAHomeNetwork() async {
        await withLocationPermission(.authorizedWhenInUse) {
            let result = await requirements(for: server(ssids: [], hardwareAddresses: ["00:00:00:00:00:01"]))
            #expect(!result.contains(.homeNetworkMissing))
            #expect(!result.contains(.locationPermission))
        }
    }

    @Test(arguments: [true, false])
    func rendersWithAndWithoutRequirements(hasHomeNetwork: Bool) async {
        await withLocationPermission(hasHomeNetwork ? .authorizedAlways : .notDetermined) {
            let controller = UIHostingController(rootView: ConnectionSecurityLevelBlockView(
                server: server(ssids: hasHomeNetwork ? ["Home"] : nil)
            ))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1000))
            window.rootViewController = controller
            window.isHidden = false
            controller.view.layoutIfNeeded()
            // Give the requirements task that `onAppear` starts its turn, then lay out what it found.
            for _ in 0 ..< 20 {
                await Task.yield()
            }
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()

            NotificationCenter.default.post(
                name: .locationPermissionDidChange,
                object: nil,
                userInfo: ["permissionState": LocationPermissionState.notDetermined]
            )
            controller.view.layoutIfNeeded()

            window.isHidden = true
            window.rootViewController = nil
        }
    }
}
