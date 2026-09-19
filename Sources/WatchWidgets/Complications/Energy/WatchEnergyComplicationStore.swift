import Foundation
import HAWatchComplications

/// The widget extension's window onto the energy payloads the watch app leaves in the shared app
/// group — one per server, written whenever the app refreshes complications.
///
/// Read-only by design. Energy preferences and long-term statistics are websocket commands, and this
/// extension deliberately links nothing heavier than `URLSession`, so unlike the entity
/// complications there is no self fetch to fall back on: the face shows what the app last read.
enum WatchEnergyComplicationStore {
    static func snapshots() -> [EnergyComplicationSnapshot] {
        EnergyComplicationSnapshot.read(from: UserDefaults(suiteName: WatchWidgetConstants.appGroupID))
    }

    /// The snapshot a complication instance renders.
    ///
    /// A configured server that no longer resolves falls back to the first one rather than blanking:
    /// the id can go stale — the server was removed, or the app was reinstalled — and a home with one
    /// server should not have to re-pick a complication it never chose a server for in the first
    /// place.
    static func snapshot(serverId: String?) -> EnergyComplicationSnapshot? {
        let snapshots = snapshots()
        if let serverId, let match = snapshots.first(where: { $0.serverId == serverId }) {
            return match
        }
        return snapshots.first
    }

    /// Whether the face should caption a complication with its server's name: only worth the line
    /// when there is more than one server to tell apart.
    static func showsServerName() -> Bool {
        snapshots().count > 1
    }
}
