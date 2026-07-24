import CoreLocation
import Foundation
import MapKit
import Shared

/// Backs `ServerSwitchingSettingsView`: takes a one-shot location fix and exposes the server the
/// by-location switching considers closest, with a human-readable distance to its nearest zone.
@MainActor
final class ServerSwitchingSettingsViewModel: NSObject, ObservableObject {
    /// E.g. "Casa · 1.2 km", or `nil` while no location fix is available or no server has zones.
    @Published private(set) var closestServerDescription: String?

    private let locationManager = CLLocationManager()
    private let distanceFormatter = with(MKDistanceFormatter()) {
        $0.unitStyle = .abbreviated
    }

    init(closestServerDescription: String? = nil) {
        self.closestServerDescription = closestServerDescription
        super.init()
        locationManager.delegate = self
    }

    func onAppear() {
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

    private func updateClosestServer(for location: CLLocation) {
        guard let closest = LocationBasedServerSwitcher.closestServer(to: location) else {
            closestServerDescription = nil
            return
        }
        let distance = distanceFormatter.string(fromDistance: closest.distance)
        closestServerDescription = "\(closest.server.info.name) · \(distance)"
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
            self?.updateClosestServer(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Current.Log.error("Server switching one-shot location failed: \(error.localizedDescription)")
    }
}
