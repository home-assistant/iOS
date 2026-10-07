import Foundation
@testable import Shared

/// In-memory registration store for tests. `writeError` makes every write fail, the way a Keychain
/// that refuses the write would.
final class FakeWatchDeviceRegistrationStore: WatchDeviceRegistrationStore {
    private let lock = NSLock()
    private var storage = [Identifier<Server>: WatchDeviceRegistration]()

    var writeError: Error?

    var all: [Identifier<Server>: WatchDeviceRegistration] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func registration(for server: Identifier<Server>) -> WatchDeviceRegistration? {
        lock.lock()
        defer { lock.unlock() }
        return storage[server]
    }

    func set(_ registration: WatchDeviceRegistration?, for server: Identifier<Server>) throws {
        lock.lock()
        defer { lock.unlock() }
        if let writeError {
            throw writeError
        }
        storage[server] = registration
    }
}
