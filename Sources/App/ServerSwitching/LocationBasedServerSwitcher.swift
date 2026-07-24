import CoreLocation
import Foundation
import Shared
import UIKit

/// Opens the server whose home the user is at when the app becomes active — arriving at a second
/// home brings up that home's server, like Apple Home selecting the home you're at. Being at a home
/// means being on its Wi-Fi network (the internal-URL SSIDs) or inside its `zone.home`; the same
/// signals, in the same priority, drive the "Closest Server" row so what's shown is what switches.
/// Runs on cold launch and on every return from the background via `didBecomeActive`; foreground
/// only, one check per activation, no background monitoring. A match is applied once per visit, so
/// manually switching away isn't undone on the next activation.
@MainActor
final class LocationBasedServerSwitcher {
    static let shared = LocationBasedServerSwitcher()

    private static let toastID = "location-based-server-switch"
    private static let toastDuration: TimeInterval = 4
    private static let locationTimeout: TimeInterval = 5

    private var didBecomeActiveObserver: NSObjectProtocol?
    private var evaluationTask: Task<Void, Never>?
    /// The server the previous evaluation matched. A new match is only applied when it differs, so a
    /// user who manually switched away stays put until they leave the home and come back.
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
        guard evaluationTask == nil else { return }

        evaluationTask = Task { [weak self] in
            // The Wi-Fi check works even without a location fix (and resolves faster than one).
            let ssid = await Current.connectivity.currentWiFiSSID()

            var location: CLLocation?
            let authorizationStatus = CLLocationManager().authorizationStatus
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                location = await withCheckedContinuation { continuation in
                    CLLocationManager.oneShotLocation(timeout: Self.locationTimeout)
                        .done { continuation.resume(returning: $0) }
                        .catch { _ in continuation.resume(returning: nil) }
                }
            }
            guard let self else { return }
            evaluationTask = nil
            guard ssid != nil || location != nil else { return }
            apply(location: location, currentSSID: ssid)
        }
    }

    private func apply(location: CLLocation?, currentSSID: String?) {
        let currentServerIdentifier = Current.settingsStore.lastActiveServerIdentifier
            .map(Identifier<Server>.init(rawValue:))
        let matched = Self.matchedServer(
            for: location,
            currentSSID: currentSSID,
            preferring: currentServerIdentifier
        )
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

    /// The server whose home the user is at — on its network, or inside its `zone.home` — or `nil`
    /// to stay put. The current server always wins when it also matches, so overlapping homes never
    /// pull the user away. Uses the same signals and priority as `closestServer`, but switching
    /// requires actually being there: a merely-nearest home never switches. Non-private for tests.
    nonisolated static func matchedServer(
        for location: CLLocation?,
        currentSSID: String?,
        preferring currentServerIdentifier: Identifier<Server>?
    ) -> Server? {
        let onHomeNetwork = serversOnHomeNetwork(currentSSID)
        if !onHomeNetwork.isEmpty {
            return onHomeNetwork.first { $0.identifier == currentServerIdentifier } ?? onHomeNetwork.first
        }
        guard let location else { return nil }

        // Match the smaller zone over the larger, then the closer center — mirrors AppZone.zones(of:in:).
        let byProximity: (AppZone, AppZone) -> Bool = { lhs, rhs in
            if lhs.radius != rhs.radius {
                return lhs.radius < rhs.radius
            }
            return location.distance(from: lhs.location) < location.distance(from: rhs.location)
        }
        let homeZonesByServer = trackedHomeZonesByServer()
        let matches: [(server: Server, zone: AppZone)] = Current.servers.all.compactMap { server in
            homeZonesByServer[server.identifier.rawValue]?
                .filter { $0.circularRegion.containsWithAccuracy(location) }
                .min(by: byProximity)
                .map { (server, $0) }
        }
        if let current = matches.first(where: { $0.server.identifier == currentServerIdentifier }) {
            return current.server
        }
        return matches.min { byProximity($0.zone, $1.zone) }?.server
    }

    /// The server considered closest, shown in the Server Switching settings screen. Being on a
    /// server's home network wins outright (no distance); otherwise the server whose `zone.home`
    /// center is nearest to `location` wins, with that distance — no need to be inside it.
    /// Returns `nil` when neither signal resolves a server. Non-private for tests.
    nonisolated static func closestServer(
        to location: CLLocation?,
        currentSSID: String?
    ) -> (server: Server, distance: CLLocationDistance?)? {
        if let onHomeNetwork = serversOnHomeNetwork(currentSSID).first {
            return (onHomeNetwork, nil)
        }
        guard let location else { return nil }

        let homeZonesByServer = trackedHomeZonesByServer()
        let candidates: [(server: Server, distance: CLLocationDistance?)] = Current.servers.all
            .compactMap { server in
                homeZonesByServer[server.identifier.rawValue]?
                    .map { location.distance(from: $0.location) }
                    .min()
                    .map { (server, $0) }
            }
        return candidates.min { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
    }

    /// Servers whose internal-URL SSIDs contain the current Wi-Fi network — the same signal
    /// `ConnectionInfo` uses to pick the internal URL.
    private nonisolated static func serversOnHomeNetwork(_ currentSSID: String?) -> [Server] {
        guard let currentSSID else { return [] }
        return Current.servers.all.filter { server in
            server.info.connection.internalSSIDs?.contains(currentSSID) == true
        }
    }

    /// Each server's tracked home zones (`zone.home`, the fixed entity id every Home Assistant
    /// instance uses), from a single database read.
    private nonisolated static func trackedHomeZonesByServer() -> [String: [AppZone]] {
        Dictionary(grouping: AppZone.trackedZones().filter(\.isHome), by: \.serverIdentifier)
    }
}
