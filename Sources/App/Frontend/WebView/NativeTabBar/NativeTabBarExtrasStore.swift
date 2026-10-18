import Foundation
import Shared

@MainActor
final class NativeTabBarExtrasStore {
    static let shared = NativeTabBarExtrasStore()

    static let storageKey = "nativeTabBarExtras"

    private let userDefaults: UserDefaults
    private var extrasByServer: [String: NativeTabBarExtras]

    init(userDefaults: UserDefaults = UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard) {
        self.userDefaults = userDefaults
        self.extrasByServer = Self.persistedExtras(in: userDefaults)
    }

    func extras(for serverId: String) -> NativeTabBarExtras {
        extrasByServer[serverId] ?? .standard
    }

    func setExtras(_ extras: NativeTabBarExtras, for serverId: String) {
        guard extrasByServer[serverId] != extras else { return }
        extrasByServer[serverId] = extras
        persist()
    }

    private static func persistedExtras(in userDefaults: UserDefaults) -> [String: NativeTabBarExtras] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: NativeTabBarExtras].self, from: data)
        } catch {
            Current.Log.error("Failed to decode native tab bar extras: \(error)")
            userDefaults.removeObject(forKey: storageKey)
            return [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(extrasByServer)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            Current.Log.error("Failed to persist native tab bar extras: \(error)")
        }
    }
}
