import CoreLocation
import Foundation
import Shared
import UIKit

/// Opens the server whose zone the user is standing in when the app becomes active — arriving at a
/// second home brings up that home's server, like Apple Home selecting the home you're at. Foreground
/// only: one location fix per activation, no background monitoring. A match is applied once per zone
/// visit, so manually switching away isn't undone on the next activation.
@MainActor
final class LocationBasedServerSwitcher {
    static let shared = LocationBasedServerSwitcher()

    private static let toastID = "location-based-server-switch"
    private static let toastDuration: TimeInterval = 4
    private static let locationTimeout: TimeInterval = 5

    private var didBecomeActiveObserver: NSObjectProtocol?
    private var evaluationTask: Task<Void, Never>?
    /// The server the previous evaluation matched. A new match is only applied when it differs, so a
    /// user who manually switched away stays put until they leave the zone and come back.
    private var lastMatchedServerIdentifier: Identifier<Server>?

    func start() {
        guard didBecomeActiveObserver == nil else { return }
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.evaluate()
            }
        }
    }

    func evaluate() {
        guard Current.settingsStore.locationBasedServerSwitching,
              // Kiosk mode pins the app to its configured server.
              !Current.kioskSettings.enabled,
              Current.servers.all.count > 1 else { return }
        let authorizationStatus = CLLocationManager().authorizationStatus
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else { return }
        guard evaluationTask == nil else { return }

        evaluationTask = Task { [weak self] in
            let location: CLLocation? = await withCheckedContinuation { continuation in
                CLLocationManager.oneShotLocation(timeout: Self.locationTimeout)
                    .done { continuation.resume(returning: $0) }
                    .catch { _ in continuation.resume(returning: nil) }
            }
            guard let self else { return }
            evaluationTask = nil
            guard let location else { return }
            apply(location: location)
        }
    }

    private func apply(location: CLLocation) {
        let currentServerIdentifier = Current.settingsStore.lastActiveServerIdentifier
            .map(Identifier<Server>.init(rawValue:))
        let matched = Self.matchedServer(for: location, preferring: currentServerIdentifier)
        defer { lastMatchedServerIdentifier = matched?.identifier }
        guard let matched,
              matched.identifier != lastMatchedServerIdentifier,
              matched.identifier != currentServerIdentifier else { return }

        Current.Log.info("location-based server switch to \(matched.identifier)")
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.open(server: matched)
        }
        if #available(iOS 18, *) {
            ToastPresenter.shared.show(
                id: Self.toastID,
                symbol: .arrowLeftArrowRight,
                symbolForegroundStyle: (.white, .haPrimary),
                title: L10n.Settings.ServerSwitching.switchedToast(matched.info.name),
                duration: Self.toastDuration
            )
        }
    }

    /// The server whose zone contains `location`, or `nil` when no server's zone does. The current
    /// server wins whenever one of its zones contains the location (overlapping zones across servers
    /// never pull the user away); otherwise the smallest matching zone — then the closest center —
    /// decides, mirroring the zone matching used for location submission. Non-private for tests.
    nonisolated static func matchedServer(
        for location: CLLocation,
        preferring currentServerIdentifier: Identifier<Server>?
    ) -> Server? {
        // A single read for every server's zones; this runs on each app activation when enabled.
        let zonesByServer = Dictionary(grouping: AppZone.trackedZones(), by: \.serverIdentifier)
        // Match the smaller zone over the larger, then the closer center — mirrors AppZone.zones(of:in:).
        let byProximity: (AppZone, AppZone) -> Bool = { lhs, rhs in
            if lhs.radius != rhs.radius {
                return lhs.radius < rhs.radius
            }
            return location.distance(from: lhs.location) < location.distance(from: rhs.location)
        }
        let matches: [(server: Server, zone: AppZone)] = Current.servers.all.compactMap { server in
            (zonesByServer[server.identifier.rawValue] ?? [])
                .filter { $0.circularRegion.containsWithAccuracy(location) }
                .min(by: byProximity)
                .map { (server, $0) }
        }
        if let current = matches.first(where: { $0.server.identifier == currentServerIdentifier }) {
            return current.server
        }
        return matches.min { byProximity($0.zone, $1.zone) }?.server
    }
}
