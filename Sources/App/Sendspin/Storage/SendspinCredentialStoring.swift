import Foundation

/// Where this device keeps the secrets Sendspin's encryption rests on. All of it survives app
/// restarts; none of it is shared with other devices.
protocol SendspinCredentialStoring: AnyObject {
    /// Created on first use and kept for good, since it is this player's identity to every server.
    func identity() -> SendspinIdentity
    /// The secret inside the pairing token. Pairing does not consume it.
    func pairingPsk() -> SendspinPsk
    func pairingRecords() -> [SendspinPairingRecord]
    func savePairingRecords(_ records: [SendspinPairingRecord])
    /// The server that last held a connection with playback active, which wins ties between two
    /// idle servers.
    var lastPlaybackServerID: String? { get set }
}

extension SendspinCredentialStoring {
    /// The specification requires room for at least five records.
    static var pairingRecordCapacity: Int { 8 }

    func pairingRecord(pskID: String) -> SendspinPairingRecord? {
        pairingRecords().first { $0.pskValue?.identifier == pskID }
    }

    /// Persists a new record, replacing any for the same server and evicting the least recently
    /// used other server when full.
    func storePairingRecord(_ record: SendspinPairingRecord) {
        var records = pairingRecords().filter { $0.serverID != record.serverID }
        while records.count >= Self.pairingRecordCapacity,
              let oldest = records.min(by: { $0.lastUsed < $1.lastUsed }) {
            records.removeAll { $0.serverID == oldest.serverID }
        }
        records.append(record)
        savePairingRecords(records)
    }

    func markPairingRecordUsed(serverID: String, at date: Date) {
        var records = pairingRecords()
        guard let index = records.firstIndex(where: { $0.serverID == serverID }) else { return }
        records[index].lastUsed = date
        savePairingRecords(records)
    }

    func removePairingRecord(serverID: String) {
        savePairingRecords(pairingRecords().filter { $0.serverID != serverID })
    }
}
