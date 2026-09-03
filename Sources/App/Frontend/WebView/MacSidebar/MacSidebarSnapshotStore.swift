import Foundation
import Shared

/// Per-server cache of the native sidebar's last resolved layout, shared by every window and persisted so
/// the first window of a launch starts from it too. Writes are skipped when the snapshot is unchanged,
/// which is the common case once the sidebar has settled.
@MainActor
final class MacSidebarSnapshotStore {
    static let shared = MacSidebarSnapshotStore()

    private static let storageKey = "macSidebarSnapshots"

    private let userDefaults: UserDefaults
    private var snapshots: [String: MacSidebarSnapshot]

    init(userDefaults: UserDefaults = UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard) {
        self.userDefaults = userDefaults
        self.snapshots = Self.persistedSnapshots(in: userDefaults)
    }

    func snapshot(for serverId: String) -> MacSidebarSnapshot? {
        snapshots[serverId]
    }

    func store(_ snapshot: MacSidebarSnapshot, for serverId: String) {
        guard snapshots[serverId] != snapshot else { return }
        snapshots[serverId] = snapshot
        persist()
    }

    private static func persistedSnapshots(in userDefaults: UserDefaults) -> [String: MacSidebarSnapshot] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: MacSidebarSnapshot].self, from: data)
        } catch {
            Current.Log.error("Failed to decode cached native sidebar snapshots: \(error)")
            return [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(snapshots)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            Current.Log.error("Failed to cache native sidebar snapshots: \(error)")
        }
    }
}
