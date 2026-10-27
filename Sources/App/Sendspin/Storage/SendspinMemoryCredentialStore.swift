import Foundation

/// Credentials that live only as long as the object: for previews, and for tests that must not
/// touch the keychain of the machine running them.
final class SendspinMemoryCredentialStore: SendspinCredentialStoring {
    private let storedIdentity: SendspinIdentity
    private let storedPairingPsk: SendspinPsk
    private var records: [SendspinPairingRecord]
    var lastPlaybackServerID: String?

    init(
        identity: SendspinIdentity = .generate(),
        pairingPsk: SendspinPsk = .generate(),
        records: [SendspinPairingRecord] = []
    ) {
        self.storedIdentity = identity
        self.storedPairingPsk = pairingPsk
        self.records = records
    }

    func identity() -> SendspinIdentity { storedIdentity }
    func pairingPsk() -> SendspinPsk { storedPairingPsk }
    func pairingRecords() -> [SendspinPairingRecord] { records }
    func savePairingRecords(_ records: [SendspinPairingRecord]) { self.records = records }
}
