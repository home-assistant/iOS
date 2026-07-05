import CoreLocation
import Foundation
import PromiseKit
import RealmSwift

/// Decides which server the app should display based on where the user currently is, similar to how
/// Apple Home selects the current home. A server is considered "current" when the device is connected
/// to one of its internal SSIDs (or hardware addresses on macOS), or is located inside one of its zones.
///
/// A manual server selection wins over the location-based server for a grace period, so switching to
/// another server on purpose isn't immediately undone when the app returns to the foreground.
public protocol LocationBasedServerSwitcher {
    /// Whether automatic switching is currently applicable: the user setting is on, more than one
    /// server is configured, and kiosk mode (which pins a specific server) is off.
    var isEnabled: Bool { get }

    /// The server the user explicitly switched to, while the manual-selection grace period is active.
    var activeManualSelection: Server? { get }

    /// Best-effort synchronous evaluation from cached state (last known SSID and the zone state kept
    /// up to date by region monitoring). Used at launch, before async lookups have a chance to run.
    func preferredServerUsingCachedState() -> Server?

    /// Full evaluation: refreshes the current network information and falls back to a one-shot
    /// location to test zone membership. Returns nil when no single server clearly matches.
    func preferredServer() async -> Server?

    /// Records that the user intentionally switched to `server`, starting the grace period during
    /// which the app won't automatically switch away from it.
    func recordManualSelection(of server: Server)

    /// Whether `server` was manually selected and the grace period hasn't elapsed yet.
    func isManualSelectionActive(for server: Server) -> Bool
}

public final class LocationBasedServerSwitcherImpl: LocationBasedServerSwitcher {
    /// How long a manual server selection is honored before the location-based server wins again.
    public static let defaultGracePeriod: TimeInterval = 15 * 60

    private enum PrefsKey {
        static let manualSelectionServer = "locationBasedServerSwitchManualSelectionServer"
        static let manualSelectionDate = "locationBasedServerSwitchManualSelectionDate"
    }

    private let prefs: UserDefaults
    private let gracePeriod: TimeInterval
    private let refreshNetworkInformation: () async -> Void
    private let locationAuthorization: () -> CLAuthorizationStatus
    private let oneShotLocation: () async throws -> CLLocation

    public init(
        prefs: UserDefaults = UserDefaults(suiteName: AppConstants.AppGroupID)!,
        gracePeriod: TimeInterval = LocationBasedServerSwitcherImpl.defaultGracePeriod,
        refreshNetworkInformation: (() async -> Void)? = nil,
        locationAuthorization: (() -> CLAuthorizationStatus)? = nil,
        oneShotLocation: (() async throws -> CLLocation)? = nil
    ) {
        self.prefs = prefs
        self.gracePeriod = gracePeriod
        self.refreshNetworkInformation = refreshNetworkInformation ?? {
            await Current.connectivity.syncNetworkInformation()
        }
        self.locationAuthorization = locationAuthorization ?? { Current.location.permissionStatus }
        self.oneShotLocation = oneShotLocation ?? Self.currentLocation
    }

    public var isEnabled: Bool {
        Current.settingsStore.locationBasedServerSwitchEnabled
            && Current.servers.all.count > 1
            && !Current.kioskSettings.enabled
    }

    public var activeManualSelection: Server? {
        guard let identifier = prefs.string(forKey: PrefsKey.manualSelectionServer),
              let date = prefs.object(forKey: PrefsKey.manualSelectionDate) as? Date,
              Current.date().timeIntervalSince(date) < gracePeriod else {
            return nil
        }
        return Current.servers.server(forServerIdentifier: identifier)
    }

    public func recordManualSelection(of server: Server) {
        prefs.set(server.identifier.rawValue, forKey: PrefsKey.manualSelectionServer)
        prefs.set(Current.date(), forKey: PrefsKey.manualSelectionDate)
    }

    public func isManualSelectionActive(for server: Server) -> Bool {
        activeManualSelection?.identifier == server.identifier
    }

    public func preferredServerUsingCachedState() -> Server? {
        guard isEnabled else { return nil }
        if let server = onlyCandidate(serversMatchingCurrentNetwork()) {
            return server
        }
        return onlyCandidate(serversWithOccupiedZone())
    }

    public func preferredServer() async -> Server? {
        guard isEnabled else { return nil }

        await refreshNetworkInformation()
        if let server = onlyCandidate(serversMatchingCurrentNetwork()) {
            return server
        }

        switch locationAuthorization() {
        case .authorizedAlways, .authorizedWhenInUse:
            if let location = try? await oneShotLocation() {
                return onlyCandidate(servers(containing: location))
            }
            // Couldn't get a fresh location in time; fall back to the zone state region monitoring keeps.
            return onlyCandidate(serversWithOccupiedZone())
        default:
            return onlyCandidate(serversWithOccupiedZone())
        }
    }

    // MARK: - Matching

    /// Switching is only ever done to an unambiguous winner; when several servers match (e.g. two
    /// servers sharing one Wi-Fi network) no switch happens rather than picking arbitrarily.
    private func onlyCandidate(_ candidates: [Server]) -> Server? {
        candidates.count == 1 ? candidates.first : nil
    }

    /// Servers whose connection considers the current network "internal" — same signal `activeURL()`
    /// uses to pick the internal URL (SSIDs everywhere, hardware addresses on macOS).
    private func serversMatchingCurrentNetwork() -> [Server] {
        Current.servers.all.filter(\.info.connection.isOnInternalNetwork)
    }

    private func servers(containing location: CLLocation) -> [Server] {
        Current.servers.all.filter { server in
            !RLMZone.zones(of: location, in: server, includingPassive: false).isEmpty
        }
    }

    /// Servers with at least one zone the device is currently known to be inside, per the `inRegion`
    /// state maintained by region monitoring. Stale when background location access is unavailable,
    /// which is why it's only the fallback to a fresh one-shot location.
    private func serversWithOccupiedZone() -> [Server] {
        let occupiedServerIdentifiers = Set(
            Current.realm()
                .objects(RLMZone.self)
                .filter("inRegion == true && TrackingEnabled == true && isPassive == false")
                .map(\.serverIdentifier)
        )
        return Current.servers.all.filter { occupiedServerIdentifiers.contains($0.identifier.rawValue) }
    }

    private static func currentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            // remaining: 10 bounds the one-shot to a few seconds so a foreground evaluation can't
            // leave the app on a stale server for long when GPS is slow.
            Current.location.oneShotLocation(.Manual, 10).done { location in
                continuation.resume(returning: location)
            }.catch { error in
                continuation.resume(throwing: error)
            }
        }
    }
}
