import Foundation
import KeychainAccess
import Shared

/// Keychain-backed storage for everything a Sendspin session authenticates with: this device's
/// Curve25519 identity, its pairing PSK, and the long-term PSKs pairing has produced.
///
/// The identity and the pairing PSK are per-device secrets drawn from the system CSPRNG. Rotating
/// the identity changes the `client_id`, so every server sees a brand new device — which is exactly
/// what "forget everything" in settings should do.
struct SendspinCredentialsStore {
    /// The specification requires at least five records, and that pairing never fails for want of
    /// storage, so a full store evicts its least recently used entry.
    static let recordCapacity = 8

    private static let identityKey = "sendspin.identity.secret"
    private static let pairingPskKey = "sendspin.pairing.psk"
    private static let recordsKey = "sendspin.pairing.records"

    private var keychain: KeychainAccess.Keychain { AppConstants.Keychain }

    /// The device identity, generating and persisting one on first use.
    func identity() -> SendspinIdentity {
        let stored = try? keychain.getData(Self.identityKey)
        if let stored, let identity = SendspinIdentity(secretKeyBytes: stored) {
            return identity
        }
        let identity = SendspinIdentity.generate()
        try? keychain.set(identity.secretKeyBytes, key: Self.identityKey)
        return identity
    }

    /// The pairing PSK, which must stay among the handshake candidates for the device's whole life:
    /// a server re-handshakes to it whenever an operator starts pairing.
    func pairingPsk() -> SendspinPsk {
        if let stored = try? keychain.getData(Self.pairingPskKey), let psk = SendspinPsk(bytes: stored) {
            return psk
        }
        let psk = SendspinPsk.generate()
        try? keychain.set(psk.bytes, key: Self.pairingPskKey)
        return psk
    }

    func pairingRecords() -> [SendspinPairingRecord] {
        guard
            let data = try? keychain.getData(Self.recordsKey),
            let records = try? JSONDecoder().decode([SendspinPairingRecord].self, from: data)
        else {
            return []
        }
        return records
    }

    /// Persists a record, replacing any the client already holds for the same server.
    func store(record: SendspinPairingRecord) {
        var records = pairingRecords().filter { $0.serverId != record.serverId }
        records.append(record)
        if records.count > Self.recordCapacity {
            records.sort { $0.lastUsed < $1.lastUsed }
            records.removeFirst(records.count - Self.recordCapacity)
        }
        write(records)
    }

    func markRecordUsed(pskId: String) {
        var records = pairingRecords()
        guard let index = records.firstIndex(where: { $0.pskId == pskId }) else { return }
        records[index].lastUsed = Current.date()
        write(records)
    }

    func removeRecord(serverId: String) {
        write(pairingRecords().filter { $0.serverId != serverId })
    }

    /// Forgets every pairing and rotates the identity, so servers no longer recognise this device.
    func reset() {
        try? keychain.remove(Self.recordsKey)
        try? keychain.remove(Self.pairingPskKey)
        try? keychain.remove(Self.identityKey)
    }

    private func write(_ records: [SendspinPairingRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        do {
            try keychain.set(data, key: Self.recordsKey)
        } catch {
            Current.Log.error("Failed to persist Sendspin pairing records: \(error)")
        }
    }
}
