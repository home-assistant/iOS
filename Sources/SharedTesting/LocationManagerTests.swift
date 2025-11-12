import CoreLocation
import Foundation
@testable @preconcurrency import Shared
import Testing

// MARK: - Mock LocationManager for Testing

final class MockLocationManager: LocationManagerProtocol {
    var mockPermissionState: LocationPermissionState = .notDetermined
    var mockAccuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    var mockLocationServicesEnabled: Bool = true
    var requestLocationPermissionCalled = false

    var currentPermissionState: LocationPermissionState {
        mockPermissionState
    }

    var accuracyAuthorization: CLAccuracyAuthorization {
        mockAccuracyAuthorization
    }

    var isLocationServicesEnabled: Bool {
        mockLocationServicesEnabled
    }

    func requestLocationPermission() {
        requestLocationPermissionCalled = true
    }

    // Helper method to simulate permission state changes
    func simulatePermissionStateChange(to newState: LocationPermissionState) {
        mockPermissionState = newState
        let userInfo = ["permissionState": newState]
        NotificationCenter.default.post(
            name: .locationPermissionDidChange,
            object: self,
            userInfo: userInfo
        )
    }
}

// MARK: - Tests

@Suite("LocationManager Tests")
struct LocationManagerTests {
    @Test("LocationPermissionState initialization from CLAuthorizationStatus")
    func locationPermissionStateInitialization() async throws {
        #expect(LocationPermissionState(from: .notDetermined) == .notDetermined)
        #expect(LocationPermissionState(from: .denied) == .denied)
        #expect(LocationPermissionState(from: .restricted) == .restricted)
        #expect(LocationPermissionState(from: .authorizedWhenInUse) == .authorizedWhenInUse)
        #expect(LocationPermissionState(from: .authorizedAlways) == .authorizedAlways)
    }

    @Test("MockLocationManager returns correct permission state")
    func mockLocationManagerPermissionState() async throws {
        let mockManager = MockLocationManager()
        mockManager.mockPermissionState = .authorizedWhenInUse

        #expect(mockManager.currentPermissionState == .authorizedWhenInUse)
    }

    @Test("MockLocationManager tracks method calls")
    func mockLocationManagerMethodCalls() async throws {
        let mockManager = MockLocationManager()

        #expect(!mockManager.requestLocationPermissionCalled)

        mockManager.requestLocationPermission()
        #expect(mockManager.requestLocationPermissionCalled)
    }

    @Test("MockLocationManager returns correct accuracy authorization")
    func mockLocationManagerAccuracyAuthorization() async throws {
        let mockManager = MockLocationManager()
        mockManager.mockAccuracyAuthorization = .reducedAccuracy

        #expect(mockManager.accuracyAuthorization == .reducedAccuracy)
    }
}
