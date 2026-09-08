import Foundation
import Shared

/// Which sidebar pages the user pinned to the native tab bar, per server. Missing means the user never
/// customised the bar, so the tab bar falls back to the first pages of the sidebar order.
@MainActor
final class NativeTabBarConfigurationStore {
    static let shared = NativeTabBarConfigurationStore()

    static let storageKey = "nativeTabBarItems"
    static let maximumTabs = 3

    private let userDefaults: UserDefaults
    private var itemIdsByServer: [String: [String]]

    init(userDefaults: UserDefaults = UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard) {
        self.userDefaults = userDefaults
        self.itemIdsByServer = Self.persistedItemIds(in: userDefaults)
    }

    func itemIds(for serverId: String) -> [String]? {
        itemIdsByServer[serverId]
    }

    func setItemIds(_ itemIds: [String], for serverId: String) {
        let itemIds = Array(itemIds.prefix(Self.maximumTabs))
        guard itemIdsByServer[serverId] != itemIds else { return }
        itemIdsByServer[serverId] = itemIds
        persist()
    }

    private static func persistedItemIds(in userDefaults: UserDefaults) -> [String: [String]] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: [String]].self, from: data)
        } catch {
            Current.Log.error("Failed to decode native tab bar configuration: \(error)")
            userDefaults.removeObject(forKey: storageKey)
            return [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(itemIdsByServer)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            Current.Log.error("Failed to persist native tab bar configuration: \(error)")
        }
    }
}
