import CoreLocation
import Foundation
import RealmSwift
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

    private let locationManager = CLLocationManager()
    private var zonesToken: NotificationToken?
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
        zonesToken?.invalidate()
        if let backgroundRefreshObserver {
            NotificationCenter.default.removeObserver(backgroundRefreshObserver)
        }
    }

    func onAppear() {
        // Pick up any changes that may have occurred while the view was off-screen.
        locationAuthorizationStatus = locationManager.authorizationStatus
        locationAccuracyAuthorization = locationManager.accuracyAuthorization
        backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
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

    // MARK: - Zones

    private func observeZones() {
        let results = Current.realm().objects(RLMZone.self)
        // Realm calls this back on the thread the observation was set up on (main).
        // Map to value-type snapshots synchronously (eagerly into an Array — Realm's
        // `.map` returns a `LazyMapSequence`, not `[T]`), then hop to MainActor to
        // publish.
        zonesToken = results.observe { [weak self] _ in
            let snapshot = Array(results).map(LocationZoneItem.init)
            Task { @MainActor [weak self] in
                self?.zones = snapshot
            }
        }
        zones = Array(results).map(LocationZoneItem.init)
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
        }
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

    init(zone: RLMZone) {
        self.id = zone.identifier
        self.name = zone.Name
        self.trackingEnabled = zone.TrackingEnabled
        self.coordinate = zone.center
        self.radius = zone.Radius
        self.beaconUUID = zone.BeaconUUID
        if let major = zone.BeaconMajor.value {
            self.beaconMajor = String(describing: major)
        } else {
            self.beaconMajor = nil
        }
        if let minor = zone.BeaconMinor.value {
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
