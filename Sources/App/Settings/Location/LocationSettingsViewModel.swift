import CoreLocation
import Foundation
import GRDB
import MapKit
import Shared
import UIKit

/// View model backing `LocationSettingsView`. Tracks permission status, background refresh status,
/// the persisted location-source toggles and exposes the list of zones for display.
@MainActor
final class LocationSettingsViewModel: NSObject, ObservableObject {
    // MARK: - Permissions

    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var locationAccuracyAuthorization: CLAccuracyAuthorization
    @Published private(set) var backgroundRefreshStatus: UIBackgroundRefreshStatus

    // MARK: - Location source toggles

    @Published var zoneEnabled: Bool {
        didSet { writeLocationSources() }
    }

    @Published var backgroundFetchEnabled: Bool {
        didSet { writeLocationSources() }
    }

    @Published var significantLocationChangeEnabled: Bool {
        didSet { writeLocationSources() }
    }

    @Published var pushNotificationsEnabled: Bool {
        didSet { writeLocationSources() }
    }

    // MARK: - Zones

    @Published private(set) var zones: [LocationZoneItem] = []

    /// Latest one-shot fix used to show each zone's distance from the user.
    @Published private(set) var currentLocation: CLLocation?

    private let distanceFormatter = with(MKDistanceFormatter()) {
        $0.unitStyle = .abbreviated
    }

    private let locationManager = CLLocationManager()
    private var zonesToken: AnyDatabaseCancellable?
    private var backgroundRefreshObserver: NSObjectProtocol?

    override init() {
        let sources = Current.settingsStore.locationSources

        let probe = CLLocationManager()
        self.locationAuthorizationStatus = probe.authorizationStatus
        self.locationAccuracyAuthorization = probe.accuracyAuthorization
        self.backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus

        self.zoneEnabled = sources.zone
        self.backgroundFetchEnabled = sources.backgroundFetch
        self.significantLocationChangeEnabled = sources.significantLocationChange
        self.pushNotificationsEnabled = sources.pushNotifications

        super.init()

        locationManager.delegate = self

        self.backgroundRefreshObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.backgroundRefreshStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let status = UIApplication.shared.backgroundRefreshStatus
            Task { @MainActor [weak self] in
                self?.backgroundRefreshStatus = status
            }
        }

        observeZones()
    }

    deinit {
        zonesToken?.cancel()
        if let backgroundRefreshObserver {
            NotificationCenter.default.removeObserver(backgroundRefreshObserver)
        }
    }

    func onAppear() {
        // Pick up any changes that may have occurred while the view was off-screen.
        locationAuthorizationStatus = locationManager.authorizationStatus
        locationAccuracyAuthorization = locationManager.accuracyAuthorization
        backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
        requestCurrentLocationIfAuthorized()
    }

    // MARK: - Permission descriptions

    var locationPermissionDescription: String {
        switch locationAuthorizationStatus {
        case .authorizedAlways:
            return L10n.SettingsDetails.Location.LocationPermission.always
        case .authorizedWhenInUse:
            return L10n.SettingsDetails.Location.LocationPermission.whileInUse
        case .denied, .restricted:
            return L10n.SettingsDetails.Location.LocationPermission.never
        case .notDetermined:
            return L10n.SettingsDetails.Location.LocationPermission.needsRequest
        @unknown default:
            return L10n.SettingsDetails.Location.LocationPermission.never
        }
    }

    var locationAccuracyDescription: String {
        switch locationAccuracyAuthorization {
        case .fullAccuracy:
            return L10n.SettingsDetails.Location.LocationAccuracy.full
        case .reducedAccuracy:
            return L10n.SettingsDetails.Location.LocationAccuracy.reduced
        @unknown default:
            return L10n.SettingsDetails.Location.LocationAccuracy.reduced
        }
    }

    var backgroundRefreshDescription: String {
        switch backgroundRefreshStatus {
        case .available:
            return L10n.SettingsDetails.Location.BackgroundRefresh.enabled
        case .denied, .restricted:
            return L10n.SettingsDetails.Location.BackgroundRefresh.disabled
        @unknown default:
            return L10n.SettingsDetails.Location.BackgroundRefresh.disabled
        }
    }

    // MARK: - Disabled-state helpers

    private var isLocationPermissionAlways: Bool {
        locationAuthorizationStatus == .authorizedAlways
    }

    private var isLocationAccuracyFull: Bool {
        locationAccuracyAuthorization == .fullAccuracy
    }

    private var isBackgroundRefreshAvailable: Bool {
        backgroundRefreshStatus == .available
    }

    var isZoneToggleDisabled: Bool {
        !isLocationPermissionAlways || !isLocationAccuracyFull
    }

    var isBackgroundFetchToggleDisabled: Bool {
        !isLocationPermissionAlways || !isBackgroundRefreshAvailable
    }

    var isSignificantLocationChangeToggleDisabled: Bool {
        !isLocationPermissionAlways
    }

    var isPushNotificationsToggleDisabled: Bool {
        !isLocationPermissionAlways
    }

    // MARK: - Permission actions

    func handleLocationPermissionTap() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        } else {
            URLOpener.shared.openSettings(destination: .location, completionHandler: nil)
        }
    }

    // MARK: - Location sources persistence

    private func writeLocationSources() {
        var sources = Current.settingsStore.locationSources
        sources.zone = zoneEnabled
        sources.backgroundFetch = backgroundFetchEnabled
        sources.significantLocationChange = significantLocationChangeEnabled
        sources.pushNotifications = pushNotificationsEnabled
        Current.settingsStore.locationSources = sources
    }

    // MARK: - Current location & distances

    /// One-shot location request so zone cards can show how far away each zone is.
    /// A rough fix is enough for a human-readable distance, and it arrives faster.
    private func requestCurrentLocationIfAuthorized() {
        guard [.authorizedAlways, .authorizedWhenInUse].contains(locationManager.authorizationStatus) else {
            return
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestLocation()
    }

    func formattedDistance(to zone: LocationZoneItem) -> String? {
        guard let currentLocation else { return nil }
        let zoneLocation = CLLocation(
            latitude: zone.coordinate.latitude,
            longitude: zone.coordinate.longitude
        )
        return distanceFormatter.string(fromDistance: currentLocation.distance(from: zoneLocation))
    }

    // MARK: - Zones

    private func observeZones() {
        let observation = ValueObservation.tracking { db in
            try AppZone.fetchAll(db)
        }
        // .immediate delivers the initial value synchronously (we are created on
        // the main queue), matching the previous Realm behavior of populating
        // the zones before first render; changes also arrive on the main queue.
        zonesToken = observation.start(
            in: Current.database(),
            scheduling: .immediate,
            onError: { error in
                Current.Log.error("couldn't observe zones: \(error)")
            },
            onChange: { [weak self] zones in
                self?.zones = zones.map(LocationZoneItem.init)
            }
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationSettingsViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let accuracy = manager.accuracyAuthorization
        Task { @MainActor [weak self] in
            self?.locationAuthorizationStatus = status
            self?.locationAccuracyAuthorization = accuracy
            self?.requestCurrentLocationIfAuthorized()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.currentLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Current.Log.error("Location settings one-shot location failed: \(error.localizedDescription)")
    }
}

// MARK: - Display model for a zone

struct LocationZoneItem: Identifiable {
    let id: String
    let name: String
    let trackingEnabled: Bool
    let coordinate: CLLocationCoordinate2D
    let radius: Double
    let beaconUUID: String?
    let beaconMajor: String?
    let beaconMinor: String?

    init(zone: AppZone) {
        self.id = zone.identifier
        self.name = zone.name
        self.trackingEnabled = zone.trackingEnabled
        self.coordinate = zone.center
        self.radius = zone.radius
        self.beaconUUID = zone.beaconUUID
        if let major = zone.beaconMajor {
            self.beaconMajor = String(describing: major)
        } else {
            self.beaconMajor = nil
        }
        if let minor = zone.beaconMinor {
            self.beaconMinor = String(describing: minor)
        } else {
            self.beaconMinor = nil
        }
    }

    var formattedCoordinate: String {
        CoordinateFormatter.string(from: coordinate)
    }
}

// MARK: - Coordinate formatting

enum CoordinateFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 4
        return formatter
    }()

    static func string(from coordinate: CLLocationCoordinate2D) -> String {
        let lat = formatter.string(from: NSNumber(value: coordinate.latitude)) ?? ""
        let lng = formatter.string(from: NSNumber(value: coordinate.longitude)) ?? ""
        return "\(lat), \(lng)"
    }
}
