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
/// manually switching away isn't undone by quick app switches. The manual choice expires after the
/// app stays in the background for a while (or is relaunched), so reopening later lands on the
/// server for the home the user is at. A deep link opening the app names its own destination, so
/// switching stands down for that activation — see `deepLinkWillOpen()`.
@MainActor
final class LocationBasedServerSwitcher {
    static let shared = LocationBasedServerSwitcher()

    private static let locationTimeout: TimeInterval = 5
    /// How long the app must stay in the background before the once-per-visit memory expires and
    /// the matched server is applied again on the next activation.
    private static let matchMemoryLifetime: TimeInterval = 15 * 60

    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didEnterBackgroundObserver: NSObjectProtocol?
    private var enteredBackgroundDate: Date?
    private var evaluationTask: Task<Void, Never>?
    /// The server the previous evaluation matched. A new match is only applied when it differs, so a
    /// user who manually switched away stays put until they leave the home, come back to the app
    /// after `matchMemoryLifetime` in the background, or relaunch it.
    private var lastMatchedServerIdentifier: Identifier<Server>?
    /// Set while a deep link is opening the app: the link picked the destination, so the activation
    /// it is bringing on skips its evaluation. Only ever set with an activation still ahead, so it
    /// is consumed by that activation rather than lingering into a later one.
    private var skipNextEvaluation = false

    /// The app's activation state, telling a link that is opening the app from one handled while it
    /// is already up. Replaceable in tests.
    var applicationStateGetter: () -> UIApplication.State = { UIApplication.shared.applicationState }

    /// Whether an evaluation is in flight. Non-private for tests.
    var isEvaluating: Bool { evaluationTask != nil }

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
        didEnterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.enteredBackgroundDate = Date()
                // Backstop: the app is down, so no activation is pending to consume a skip.
                self?.skipNextEvaluation = false
            }
        }
    }

    /// Stands switching down for the activation a deep link is opening. Deep links (`homeassistant://`
    /// URLs, universal links, NFC tags, widget and App Intent taps) carry their own destination —
    /// often an explicit server — and location-based switching landing afterwards would replace what
    /// the link asked for. Call this synchronously as the link arrives, before the work that resolves
    /// its destination, so it lands whichever side of `didBecomeActive` the link is delivered on.
    func deepLinkWillOpen() {
        // An evaluation already running would finish after the link opens — it waits up to
        // `locationTimeout` for a fix — so drop its result rather than let it switch on top.
        evaluationTask?.cancel()
        evaluationTask = nil
        // Only a link that is opening the app still has an activation ahead of it, and on that
        // ordering (cold launch) the link lands before `didBecomeActive`, so the evaluation it is
        // about to start has to be skipped too. Once the app is active that notification has been
        // and gone — cancelling above is then the whole job, and a flag left set here would swallow
        // the next, unrelated activation instead.
        skipNextEvaluation = applicationStateGetter() != .active
    }

    func evaluate() {
        guard !skipNextEvaluation else {
            skipNextEvaluation = false
            return
        }
        guard Current.settingsStore.locationBasedServerSwitching,
              // Kiosk mode pins the app to its configured server.
              !Current.kioskSettings.enabled,
              Current.servers.all.count > 1 else { return }
        guard evaluationTask == nil else { return }

        // A long stay in the background ends the visit: whoever is at this home now expects the
        // matching server again, even if they had manually switched away before leaving the app.
        if let enteredBackgroundDate, Date().timeIntervalSince(enteredBackgroundDate) >= Self.matchMemoryLifetime {
            lastMatchedServerIdentifier = nil
        }
        enteredBackgroundDate = nil

        evaluationTask = Task { [weak self] in
            // The Wi-Fi check works even without a location fix (and resolves faster than one).
            let ssid = await Current.connectivity.currentWiFiSSID()
            guard !Task.isCancelled else { return }

            var location: CLLocation?
            let authorizationStatus = CLLocationManager().authorizationStatus
            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                location = await withCheckedContinuation { continuation in
                    CLLocationManager.oneShotLocation(timeout: Self.locationTimeout)
                        .done { continuation.resume(returning: $0) }
                        .catch { _ in continuation.resume(returning: nil) }
                }
            }
            // A cancelled task leaves `evaluationTask` alone: whoever cancelled it already cleared
            // the slot, and a later activation may have started a new evaluation in it.
            guard let self, !Task.isCancelled else { return }
            evaluationTask = nil
            guard ssid != nil || location != nil else { return }
            apply(location: location, currentSSID: ssid)
        }
    }

    private func apply(location: CLLocation?, currentSSID: String?) {
        // The server the app shows without our intervention — the same kiosk/last-active/first
        // resolution used at launch. Comparing against the raw stored identifier isn't enough:
        // when it's stale or unset, launch falls back to the first server, and matching that
        // fallback on a cold open must not announce a "switch" to the server already opening.
        let currentServer = OnboardingStateObservable.preferredInitialServer()
        let matched = Self.matchedServer(
            for: location,
            currentSSID: currentSSID,
            preferring: currentServer?.identifier
        )
        // Cached even when no switch follows: a picker wants the answer without a location fix.
        ServerPriority.cacheClosestServer(matched?.identifier)
        defer { lastMatchedServerIdentifier = matched?.identifier }
        guard let matched,
              matched.identifier != lastMatchedServerIdentifier,
              matched.identifier != currentServer?.identifier else { return }

        Current.Log.info("location-based server switch to \(matched.identifier)")
        Current.clientEventStore.addEvent(ClientEvent(
            text: "Switched server based on location to \(matched.info.name)",
            type: .locationUpdate,
            payload: [
                "server_name": matched.info.name,
                "server_id": matched.identifier.rawValue,
            ]
        ))
        Current.sceneManager.appCoordinator.done { coordinator in
            coordinator.open(server: matched)
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
    /// server's home network wins outright (no distance), preferring the current server when
    /// several share the SSID so the row agrees with `matchedServer`. Otherwise the server whose
    /// `zone.home` center is nearest to `location` wins, with that distance, no need to be inside
    /// it. Returns `nil` when neither signal resolves a server. Non-private for tests.
    nonisolated static func closestServer(
        to location: CLLocation?,
        currentSSID: String?,
        preferring currentServerIdentifier: Identifier<Server>?
    ) -> (server: Server, distance: CLLocationDistance?)? {
        let onHomeNetwork = serversOnHomeNetwork(currentSSID)
        if let server = onHomeNetwork.first(where: { $0.identifier == currentServerIdentifier })
            ?? onHomeNetwork.first {
            return (server, nil)
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
