import Foundation
import KeychainAccess

/// Keeps each server's watch registration in this device's own Keychain — the watch and the iPhone
/// don't share one — JSON-encoded under the server identifier. Reads hit the Keychain every time,
/// so callers stay off the main thread (see `WatchServerSync`).
public final class KeychainWatchDeviceRegistrationStore: WatchDeviceRegistrationStore {
    public static let service = "\(AppConstants.BundleID).watch-device-registration"

    private let keychain: KeychainAccess.Keychain
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(keychain: KeychainAccess.Keychain = .init(service: KeychainWatchDeviceRegistrationStore.service)) {
        self.keychain = keychain
    }

    public func registration(for server: Identifier<Server>) -> WatchDeviceRegistration? {
        do {
            guard let data = try keychain.getData(server.rawValue) else { return nil }
            return try decoder.decode(WatchDeviceRegistration.self, from: data)
        } catch {
            Current.Log.error("failed reading watch registration for \(server): \(error)")
            return nil
        }
    }

    public func set(_ registration: WatchDeviceRegistration?, for server: Identifier<Server>) throws {
        if let registration {
            try keychain.set(encoder.encode(registration), key: server.rawValue)
        } else {
            try keychain.remove(server.rawValue)
        }
    }
}
