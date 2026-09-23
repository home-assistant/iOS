import Foundation
@testable import Shared
import Testing

@Suite("Sensor registration versions")
struct SensorRegistrationVersionStoreTests {
    private func identifier() -> Identifier<Server> {
        .init(rawValue: "sensor-registration-version-test-\(UUID().uuidString)")
    }

    private func recordedVersion(for server: Identifier<Server>) -> String? {
        Current.settingsStore.prefs.string(forKey: SensorRegistrationVersionStore.key(for: server))
    }

    private func record(version: String, for server: Identifier<Server>) {
        Current.settingsStore.prefs.set(version, forKey: SensorRegistrationVersionStore.key(for: server))
    }

    @Test("A server that has never been told needs telling")
    func aNewServerNeedsRegistration() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        #expect(SensorRegistrationVersionStore.needsRegistration(for: server))
    }

    @Test("Recording a pass stores this version and settles the server")
    func recordingSettlesTheServer() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        SensorRegistrationVersionStore.recordRegistration(for: server)

        #expect(recordedVersion(for: server) == AppConstants.version)
        #expect(!SensorRegistrationVersionStore.needsRegistration(for: server))
    }

    @Test("Recording again is harmless")
    func recordingTwiceLeavesItSettled() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        SensorRegistrationVersionStore.recordRegistration(for: server)
        SensorRegistrationVersionStore.recordRegistration(for: server)

        #expect(!SensorRegistrationVersionStore.needsRegistration(for: server))
    }

    @Test("An install that upgraded needs telling again")
    func anUpgradedInstallNeedsRegistration() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        record(version: "2020.1", for: server)

        #expect(SensorRegistrationVersionStore.needsRegistration(for: server))
    }

    @Test("An install that downgraded needs telling again")
    func aDowngradedInstallNeedsRegistration() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        record(version: "9999.1", for: server)

        #expect(SensorRegistrationVersionStore.needsRegistration(for: server))
    }

    @Test("Forgetting a server registers it again")
    func forgettingRegistersAgain() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        SensorRegistrationVersionStore.recordRegistration(for: server)
        SensorRegistrationVersionStore.forgetRegistration(for: server)

        #expect(recordedVersion(for: server) == nil)
        #expect(SensorRegistrationVersionStore.needsRegistration(for: server))
    }

    @Test("Servers are tracked apart")
    func serversAreTrackedApart() {
        let first = identifier()
        let second = identifier()
        defer {
            SensorRegistrationVersionStore.forgetRegistration(for: first)
            SensorRegistrationVersionStore.forgetRegistration(for: second)
        }

        SensorRegistrationVersionStore.recordRegistration(for: first)

        #expect(!SensorRegistrationVersionStore.needsRegistration(for: first))
        #expect(SensorRegistrationVersionStore.needsRegistration(for: second))

        SensorRegistrationVersionStore.forgetRegistration(for: first)

        #expect(recordedVersion(for: second) == nil)
    }
}
