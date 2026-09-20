import Foundation
@testable import Shared
import Testing

@Suite("Sensor registration versions")
struct SensorRegistrationVersionStoreTests {
    private func identifier() -> Identifier<Server> {
        .init(rawValue: "sensor-registration-version-test-\(UUID().uuidString)")
    }

    @Test("A server that has never been told needs telling")
    func aNewServerNeedsRegistration() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        #expect(SensorRegistrationVersionStore.needsRegistration(for: server))
    }

    @Test("Recording a pass settles it until the app version moves")
    func recordingSettlesTheServer() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        SensorRegistrationVersionStore.recordRegistration(for: server)
        #expect(!SensorRegistrationVersionStore.needsRegistration(for: server))

        // What an app update looks like from here: the recorded version is no longer this one.
        Current.settingsStore.prefs.set("2020.1", forKey: "sensorRegistrationAppVersion_\(server.rawValue)")
        #expect(SensorRegistrationVersionStore.needsRegistration(for: server))
    }

    @Test("Forgetting a server registers it again")
    func forgettingRegistersAgain() {
        let server = identifier()
        defer { SensorRegistrationVersionStore.forgetRegistration(for: server) }

        SensorRegistrationVersionStore.recordRegistration(for: server)
        SensorRegistrationVersionStore.forgetRegistration(for: server)

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
    }
}
