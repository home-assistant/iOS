import CoreLocation
import Foundation
import MapKit
import Shared

/// Backs `ServerSwitchingSettingsView`: checks the current Wi-Fi and a one-shot location fix, and
/// exposes the server considered closest — by home network, or by distance to its home zone.
@MainActor
final class ServerSwitchingSettingsViewModel: NSObject, ObservableObject {
    /// E.g. "Casa · 1.2 km" (or just "Casa" when matched by Wi-Fi), `nil` while undetermined.
    @Published private(set) var closestServerDescription: String?

    private let locationManager = CLLocationManager()
    private let distanceFormatter = with(MKDistanceFormatter()) {
        $0.unitStyle = .abbreviated
    }

    private var currentSSID: String?
    private var currentLocation: CLLocation?

    init(closestServerDescription: String? = nil) {
        self.closestServerDescription = closestServerDescription
        super.init()
        locationManager.delegate = self
    }

    func onAppear() {
        guard Current.servers.all.count > 1 else { return }
        Task { [weak self] in
            let ssid = await Current.connectivity.currentWiFiSSID()
            self?.currentSSID = ssid
            self?.updateClosestServer()
        }
        requestCurrentLocationIfAuthorized()
    }

    /// One-shot fix so the screen can show which server is closest right now.
    /// A rough fix is enough for a human-readable distance, and it arrives faster.
    private func requestCurrentLocationIfAuthorized() {
        guard Current.servers.all.count > 1,
              [.authorizedAlways, .authorizedWhenInUse].contains(locationManager.authorizationStatus) else {
            return
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestLocation()
    }

    private func updateClosestServer() {
        // Prefer the currently shown server on shared networks, so the row agrees with switching.
        let currentServerIdentifier = OnboardingStateObservable.preferredInitialServer()?.identifier
        guard let closest = LocationBasedServerSwitcher.closestServer(
            to: currentLocation,
            currentSSID: currentSSID,
            preferring: currentServerIdentifier
        ) else {
            // Clear rather than keep a stale value when the signals no longer resolve a server.
            closestServerDescription = nil
            return
        }
        if let distance = closest.distance {
            let formatted = distanceFormatter.string(fromDistance: distance)
            closestServerDescription = "\(closest.server.info.name) · \(formatted)"
        } else {
            // Matched by being on the server's home network; a distance would be meaningless.
            closestServerDescription = closest.server.info.name
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension ServerSwitchingSettingsViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.requestCurrentLocationIfAuthorized()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.currentLocation = location
            self?.updateClosestServer()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Current.Log.error("Server switching one-shot location failed: \(error.localizedDescription)")
    }
}
