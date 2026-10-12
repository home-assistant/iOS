import Foundation
import KeychainAccess
import Shared

/// Keeps Sendspin's secrets in the keychain, readable after first unlock so a server can connect
/// while the phone is locked in a pocket and playing.
final class SendspinKeychainCredentialStore: SendspinCredentialStoring {
    private enum Key {
        static let identity = "identity"
        static let pairingPsk = "pairingPsk"
        static let pairingRecords = "pairingRecords"
        static let lastPlaybackServerID = "lastPlaybackServerID"
    }

    private let keychain: Keychain
    private let lock = NSLock()

    init(service: String = "io.home-assistant.sendspin") {
        self.keychain = Keychain(service: service).accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    func identity() -> SendspinIdentity {
        lock.withLock {
            if let data = try? keychain.getData(Key.identity), let identity = SendspinIdentity(privateKeyBytes: data) {
                return identity
            }
            let identity = SendspinIdentity.generate()
            store(identity.privateKeyBytes, key: Key.identity)
            return identity
        }
    }

    func pairingPsk() -> SendspinPsk {
        lock.withLock {
            if let data = try? keychain.getData(Key.pairingPsk), let psk = SendspinPsk(bytes: data) {
                return psk
            }
            let psk = SendspinPsk.generate()
            store(psk.bytes, key: Key.pairingPsk)
            return psk
        }
    }

    func pairingRecords() -> [SendspinPairingRecord] {
        lock.withLock {
            guard let data = try? keychain.getData(Key.pairingRecords) else { return [] }
            return (try? JSONDecoder().decode([SendspinPairingRecord].self, from: data)) ?? []
        }
    }

    func savePairingRecords(_ records: [SendspinPairingRecord]) {
        lock.withLock {
            guard let data = try? JSONEncoder().encode(records) else { return }
            store(data, key: Key.pairingRecords)
        }
    }

    var lastPlaybackServerID: String? {
        get { lock.withLock { try? keychain.getString(Key.lastPlaybackServerID) } }
        set {
            lock.withLock {
                if let newValue {
                    try? keychain.set(newValue, key: Key.lastPlaybackServerID)
                } else {
                    try? keychain.remove(Key.lastPlaybackServerID)
                }
            }
        }
    }

    private func store(_ data: Data, key: String) {
        do {
            try keychain.set(data, key: key)
        } catch {
            Current.Log.error("Sendspin: failed to store \(key) in the keychain: \(error)")
        }
    }
}
