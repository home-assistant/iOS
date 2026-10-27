import Foundation
@testable import HomeAssistant
import Testing

struct SendspinCredentialsTests {
    /// The specification publishes both values so every implementation agrees on them.
    @Test func sentinelMatchesTheSpecification() {
        let sentinelHex = SendspinPsk.sentinel.bytes.map { String(format: "%02x", $0) }.joined()
        #expect(sentinelHex == "1b5e24dbc1aed95fc2a5a338a90c05df44bd10f5ec1f4cd66cbf86272767b9d3")
        #expect(SendspinPsk.sentinel.identifier == "GFsV9tLaSQm9HcFWpKsgYQOr7wFTvNUtkmFwuVz3zoo")
    }

    @Test func pskRequiresThirtyTwoBytes() {
        #expect(SendspinPsk(bytes: Data(count: 31)) == nil)
        #expect(SendspinPsk(bytes: Data(count: 32)) != nil)
        #expect(SendspinPsk.generate() != SendspinPsk.generate())
    }

    @Test func base64URLRoundTripsWithoutPadding() {
        let data = Data([0xFB, 0xFF, 0xBF, 0x00])
        let encoded = SendspinBase64URL.encode(data)
        #expect(encoded == "-_-_AA")
        #expect(SendspinBase64URL.decode(encoded) == data)
        #expect(SendspinBase64URL.decode("+/+/AA") == nil)
        #expect(SendspinBase64URL.decode("AA==") == nil)
    }

    /// The specification's reference vector for a version-0 token.
    @Test func pairingTokenMatchesTheSpecification() throws {
        let clientKey = Data((0x00 ... 0x1F).map { UInt8($0) })
        let psk = try #require(SendspinPsk(bytes: Data((0xE0 ... 0xFF).map { UInt8($0) })))
        let token = SendspinPairingToken(clientKey: clientKey, pairingPsk: psk)
        let expected =
            "SP:0AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQTCQKRMFYYDENBWHA5DYP6BYPC4PSOLZXH5DU6V97M5XXO74HR6LZ7J5PW674PT6X37T6757Y"
        #expect(token.string == expected)
        #expect(SendspinPairingToken(string: expected) == token)
        // Decoding is lenient with what an operator types or pastes.
        #expect(SendspinPairingToken(string: "  " + expected.lowercased() + "\n") == token)
        #expect(SendspinPairingToken(string: String(expected.dropFirst(3))) == token)
    }

    @Test func malformedPairingTokensAreRejected() {
        #expect(SendspinPairingToken(string: "SP:1AAAA") == nil)
        #expect(SendspinPairingToken(string: "SP:0AAAA") == nil)
        #expect(SendspinPairingToken(string: "SP:0!!!!") == nil)
    }

    @Test func memoryStoreKeepsRecordsAndEvictsTheOldest() throws {
        let store = SendspinMemoryCredentialStore()
        #expect(store.identity().clientID == store.identity().clientID)
        #expect(store.pairingPsk() == store.pairingPsk())

        for index in 0 ..< SendspinMemoryCredentialStore.pairingRecordCapacity {
            store.storePairingRecord(SendspinPairingRecord(
                serverID: "server-\(index)",
                serverName: "Server \(index)",
                psk: SendspinBase64URL.encode(SendspinPsk.generate().bytes),
                lastUsed: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }
        store.markPairingRecordUsed(serverID: "server-0", at: Date(timeIntervalSince1970: 1000))
        let newest = SendspinPsk.generate()
        store.storePairingRecord(SendspinPairingRecord(
            serverID: "new",
            serverName: "New",
            psk: SendspinBase64URL.encode(newest.bytes),
            lastUsed: Date(timeIntervalSince1970: 2000)
        ))

        let ids = Set(store.pairingRecords().map(\.serverID))
        #expect(ids.count == SendspinMemoryCredentialStore.pairingRecordCapacity)
        #expect(ids.contains("server-0"))
        #expect(!ids.contains("server-1"))
        #expect(store.pairingRecord(pskID: newest.identifier)?.serverID == "new")

        store.removePairingRecord(serverID: "new")
        #expect(store.pairingRecord(pskID: newest.identifier) == nil)
    }

    @Test func keychainStoreKeepsItsSecrets() {
        let store = SendspinKeychainCredentialStore(service: "io.home-assistant.sendspin.tests.\(UUID().uuidString)")
        defer {
            store.savePairingRecords([])
            store.lastPlaybackServerID = nil
        }
        #expect(store.identity().clientID == store.identity().clientID)
        #expect(store.pairingPsk() == store.pairingPsk())
        store.lastPlaybackServerID = "server"
        #expect(store.lastPlaybackServerID == "server")
        let record = SendspinPairingRecord(serverID: "server", serverName: "Server", psk: "", lastUsed: Date())
        store.savePairingRecords([record])
        #expect(store.pairingRecords().map(\.serverID) == ["server"])
    }
}
