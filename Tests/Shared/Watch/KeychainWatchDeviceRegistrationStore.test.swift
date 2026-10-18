import Foundation
@testable import Shared
import Testing

struct KeychainWatchDeviceRegistrationStoreTests {
    private let keychain = FakeServerManagerKeychain()
    private let server = Identifier<Server>(rawValue: "server-1")

    private var registration: WatchDeviceRegistration {
        WatchDeviceRegistration(
            webhookID: "hook",
            webhookSecret: "secret",
            cloudhookURL: URL(string: "https://hooks.nabu.casa/hook"),
            registeredAt: Date(timeIntervalSince1970: 1_700_000_000),
            registeredSensorEnablement: ["battery_level": true]
        )
    }

    @Test func storesAndReadsBackPerServer() throws {
        let store = KeychainWatchDeviceRegistrationStore(keychain: keychain)

        try store.set(registration, for: server)

        #expect(store.registration(for: server) == registration)
        #expect(store.registration(for: Identifier<Server>(rawValue: "other")) == nil)
        #expect(keychain.allKeys() == ["server-1"])
    }

    @Test func forgetsARegistration() throws {
        let store = KeychainWatchDeviceRegistrationStore(keychain: keychain)
        try store.set(registration, for: server)

        try store.set(nil, for: server)

        #expect(store.registration(for: server) == nil)
        #expect(keychain.allKeys().isEmpty)
    }

    @Test func unreadableDataReadsAsNoRegistration() throws {
        try keychain.set(Data("not json".utf8), key: server.rawValue)
        let store = KeychainWatchDeviceRegistrationStore(keychain: keychain)

        #expect(store.registration(for: server) == nil)
    }

    @Test func serviceIsScopedToTheApp() {
        #expect(KeychainWatchDeviceRegistrationStore.service.hasSuffix(".watch-device-registration"))
    }
}
