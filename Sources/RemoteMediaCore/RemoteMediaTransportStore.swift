import Foundation

/// The webhook transport context, kept in storage both the app and the extension can reach.
///
/// Deliberately separate from `RemoteMediaSessionAttributes`: those are serialized through Apple's
/// RemoteMedia infrastructure, and the webhook secret must not travel that way.
public enum RemoteMediaTransportStore {
    /// The Keychain in production; an in-memory double in tests.
    public static var storage: any RemoteMediaSecureStorage = RemoteMediaKeychainStorage()

    public static func load() -> RemoteMediaTransportContext? {
        guard let data = storage.data() else { return nil }
        return try? JSONDecoder().decode(RemoteMediaTransportContext.self, from: data)
    }

    public static func save(_ context: RemoteMediaTransportContext) throws {
        try storage.save(JSONEncoder().encode(context))
    }

    public static func clear() {
        storage.clear()
    }
}
