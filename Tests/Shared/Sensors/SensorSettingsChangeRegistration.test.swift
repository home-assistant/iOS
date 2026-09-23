import PromiseKit
@testable import Shared
import Testing

/// Switching a sensor on for one server must not make the others rewrite their registrations: the
/// choice is theirs to keep, and the extra round trips are the whole cost of a toggle.
///
/// Serialized because every test swaps globals on `Current`.
@Suite("Sensor settings change registration", .serialized)
struct SensorSettingsChangeRegistrationTests {
    /// Runs the wrapped work without a real `UIApplication`/`ProcessInfo` assertion.
    private final class PassthroughBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        func callAsFunction<PromiseValue>(
            withName name: String,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            wrapping(nil)
        }
    }

    @Test func aChangeOnAnotherServerRegistersNothingHere() async throws {
        try await withServers { servers, sent in
            let mine = try #require(servers.all.first)
            let other = try #require(servers.all.last)
            let api = HomeAssistantAPI(server: mine)

            api.sensorContainer(
                Current.sensors,
                didSignalForUpdateBecause: .settingsChange(
                    changedUniqueIDs: [WebhookSensorId.activity.rawValue],
                    serverIDs: [other.identifier]
                ),
                lastUpdate: nil
            )

            // Long enough that a registration would have been sent by now: concluding "nothing
            // was sent" the instant after asking is what would pass here for the wrong reason.
            await settle { !sent.types.isEmpty }

            // The guard is what this is about: reaching `registerSensors` would put the sensor on
            // the wire for a server whose selection never moved.
            #expect(!sent.types.contains("register_sensor"))
        }
    }

    /// An empty list is a change that isn't about one server in particular — a first-run reset —
    /// and every server has to hear about it.
    @Test func aChangeWithNoServerNamedIsNotFilteredOut() async throws {
        try await withServers { servers, sent in
            let mine = try #require(servers.all.first)
            let api = HomeAssistantAPI(server: mine)

            api.sensorContainer(
                Current.sensors,
                didSignalForUpdateBecause: .settingsChange(
                    changedUniqueIDs: [WebhookSensorId.activity.rawValue],
                    serverIDs: []
                ),
                lastUpdate: nil
            )
            await settle { sent.types.contains("register_sensor") }

            #expect(sent.types.contains("register_sensor"))
        }
    }

    @Test func aChangeOnThisServerRegistersIt() async throws {
        try await withServers { servers, sent in
            let mine = try #require(servers.all.first)
            let api = HomeAssistantAPI(server: mine)

            api.sensorContainer(
                Current.sensors,
                didSignalForUpdateBecause: .settingsChange(
                    changedUniqueIDs: [WebhookSensorId.activity.rawValue],
                    serverIDs: [mine.identifier]
                ),
                lastUpdate: nil
            )
            await settle { sent.types.contains("register_sensor") }

            #expect(sent.types.contains("register_sensor"))
        }
    }

    // MARK: - Helpers

    /// Collected by reference, so the handler the webhook manager keeps writes where the test reads.
    private final class SentTypes {
        var types: [String] = []
    }

    /// Registration sends one request per sensor, so a container with no providers would send
    /// nothing and every one of these would pass for the wrong reason.
    private final class MockSensorProvider: SensorProvider {
        required init(request: SensorProviderRequest) {}

        func sensors() -> Promise<[WebhookSensor]> {
            .value([WebhookSensor(name: "Activity", uniqueID: WebhookSensorId.activity.rawValue)])
        }
    }

    /// The registration is handed through promises that resolve on the main queue, so a test
    /// reading what was sent straight afterwards would see nothing yet.
    private func settle(until condition: () -> Bool) async {
        for _ in 0 ..< 200 where !condition() {
            try? await Task.sleep(nanoseconds: 5 * NSEC_PER_MSEC)
        }
    }

    private func withServers(_ body: (FakeServerManager, SentTypes) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        let previousWebhooks = Current.webhooks
        let previousBackgroundTask = Current.backgroundTask
        defer {
            Current.servers = previousServers
            Current.sensors = previousSensors
            Current.webhooks = previousWebhooks
            Current.backgroundTask = previousBackgroundTask
            SensorEnablementStore.resetForTesting()
        }

        let servers = FakeServerManager(initial: 2)
        Current.servers = servers

        // What the webhook manager was asked to send is how "did it register?" is observed without
        // a server to send to.
        let sent = SentTypes()
        let webhooks = FakeWebhookManager()
        webhooks.sendRequestHandler = { _, _, request, seal in
            sent.types.append(request.type)
            seal.fulfill(())
        }
        Current.webhooks = webhooks
        Current.backgroundTask = PassthroughBackgroundTaskRunner()
        SensorEnablementStore.resetForTesting()
        Current.sensors = SensorContainer()
        Current.sensors.register(provider: MockSensorProvider.self)
        Current.sensors.resetSensorsForFirstRun()
        try await body(servers, sent)
    }
}
