import Foundation
import PromiseKit
@testable import Shared
import XCTest

/// Signaled sensor updates must reach every server with sensor privacy `.all` (#5100).
/// Sharing one exclusive background-task name across HomeAssistantAPI observers cancels siblings.
class SignaledSensorUpdateTests: XCTestCase {
    private var originalServers: ServerManager!
    private var originalSensors: SensorContainer!
    private var originalWebhooks: WebhookManager!
    private var originalBackgroundTask: HomeAssistantBackgroundTaskRunner!
    private var originalCachedApis: [Identifier<Server>: HomeAssistantAPI]!

    private var servers: FakeServerManager!
    private var webhookManager: FakeWebhookManager!
    private var backgroundTaskRunner: ExclusiveNameBackgroundTaskRunner!

    override func setUp() {
        super.setUp()

        SensorEnablementStore.resetForTesting()

        originalServers = Current.servers
        originalSensors = Current.sensors
        originalWebhooks = Current.webhooks
        originalBackgroundTask = Current.backgroundTask
        originalCachedApis = Current.cachedApis

        servers = FakeServerManager()
        Current.servers = servers

        let container = SensorContainer()
        container.register(provider: ImmediateTestSensorProvider.self)
        Current.sensors = container

        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager

        backgroundTaskRunner = ExclusiveNameBackgroundTaskRunner()
        Current.backgroundTask = backgroundTaskRunner

        Current.cachedApis = [:]
    }

    override func tearDown() {
        Current.servers = originalServers
        Current.sensors = originalSensors
        Current.webhooks = originalWebhooks
        Current.backgroundTask = originalBackgroundTask
        Current.cachedApis = originalCachedApis

        SensorEnablementStore.resetForTesting()
        ImmediateTestSensorProvider.lastCreated = nil

        super.tearDown()
    }

    func testSignaledUpdateSendsToEveryServerWithSensorPrivacyAll() throws {
        let (server1, server2) = makeTwoServers(privacy1: .all, privacy2: .all)
        let (api1, api2) = makeAPIs(server1: server1, server2: server2)
        withExtendedLifetime((api1, api2)) {
            let recording = startRecordingWebhookSends(expectedCount: 2)

            XCTAssertNoThrow(try fireSensorSignal())
            wait(for: [recording.expectation], timeout: 5)

            XCTAssertEqual(
                Set(recording.sends.map(\.server.identifier)),
                Set([server1.identifier, server2.identifier])
            )
            XCTAssertTrue(recording.sends.allSatisfy { $0.identifier == .updateSensors })
            XCTAssertEqual(
                Set(backgroundTaskRunner.names),
                Set([
                    "\(BackgroundTask.signaledUpdateSensors.rawValue)-\(server1.identifier.rawValue)",
                    "\(BackgroundTask.signaledUpdateSensors.rawValue)-\(server2.identifier.rawValue)",
                ])
            )
        }
    }

    func testSignaledUpdateReachesBothServersWhenListOrderIsSwapped() throws {
        let (server1, server2) = makeTwoServers(privacy1: .all, privacy2: .all)
        servers.all = [server2, server1]
        let (api1, api2) = makeAPIs(server1: server1, server2: server2)
        withExtendedLifetime((api1, api2)) {
            let recording = startRecordingWebhookSends(expectedCount: 2)

            XCTAssertNoThrow(try fireSensorSignal())
            wait(for: [recording.expectation], timeout: 5)

            XCTAssertEqual(
                Set(recording.sends.map(\.server.identifier)),
                Set([server1.identifier, server2.identifier])
            )
        }
    }

    func testSignaledUpdateSkipsServerWithSensorPrivacyNone() throws {
        let (included, excluded) = makeTwoServers(privacy1: .all, privacy2: .none)
        let (includedAPI, excludedAPI) = makeAPIs(server1: included, server2: excluded)
        withExtendedLifetime((includedAPI, excludedAPI)) {
            let recording = startRecordingWebhookSends(expectedCount: 1)

            XCTAssertNoThrow(try fireSensorSignal())
            wait(for: [recording.expectation], timeout: 5)

            XCTAssertEqual(recording.sends.map(\.server.identifier), [included.identifier])
            XCTAssertFalse(backgroundTaskRunner.names.contains {
                $0.contains(excluded.identifier.rawValue)
            })
        }
    }

    @discardableResult
    private func makeTwoServers(
        privacy1: ServerSensorPrivacy,
        privacy2: ServerSensorPrivacy
    ) -> (Server, Server) {
        let server1 = servers.addFake()
        let server2 = servers.addFake()
        server1.info.setSetting(value: privacy1, for: .sensorPrivacy)
        server2.info.setSetting(value: privacy2, for: .sensorPrivacy)
        Current.sensors.setEnabled(true, forUniqueID: ImmediateTestSensorProvider.uniqueID)
        return (server1, server2)
    }

    private func makeAPIs(server1: Server, server2: Server) -> (HomeAssistantAPI, HomeAssistantAPI) {
        let api1 = HomeAssistantAPI(server: server1)
        let api2 = HomeAssistantAPI(server: server2)
        Current.setCachedApi(api1, for: server1.identifier)
        Current.setCachedApi(api2, for: server2.identifier)
        return (api1, api2)
    }

    private func fireSensorSignal() throws {
        _ = try hang(Promise(Current.sensors.sensors(
            reason: .trigger("unit-test"),
            server: try XCTUnwrap(servers.all.first)
        )))

        let provider = try XCTUnwrap(ImmediateTestSensorProvider.lastCreated)
        let signaler: TestSensorUpdateSignaler = provider.request.dependencies.updateSignaler(for: provider)
        signaler.signal()
    }

    private func startRecordingWebhookSends(expectedCount: Int) -> WebhookSendRecording {
        let expectation = expectation(description: "webhook sends")
        expectation.expectedFulfillmentCount = expectedCount

        let recording = WebhookSendRecording(expectation: expectation)
        webhookManager.sendRequestHandler = { identifier, server, _, seal in
            recording.append(identifier: identifier, server: server)
            expectation.fulfill()
            seal.fulfill(())
        }
        return recording
    }
}

private struct WebhookSend {
    let identifier: WebhookResponseIdentifier
    let server: Server
}

private final class WebhookSendRecording {
    let expectation: XCTestExpectation
    private let lock = NSLock()
    private var _sends = [WebhookSend]()

    var sends: [WebhookSend] {
        lock.lock()
        defer { lock.unlock() }
        return _sends
    }

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func append(identifier: WebhookResponseIdentifier, server: Server) {
        lock.lock()
        _sends.append(.init(identifier: identifier, server: server))
        lock.unlock()
    }
}

/// Single-flight by name: a later task with the same name replaces an earlier sibling that
/// has not started yet, matching the exclusive-name cancellation in issue #5100.
private final class ExclusiveNameBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    private(set) var names: [String] = []
    private var latestToken = [String: UUID]()

    func callAsFunction<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        names.append(name)
        let token = UUID()
        latestToken[name] = token

        let (promise, seal) = Promise<PromiseValue>.pending()
        DispatchQueue.main.async {
            guard self.latestToken[name] == token else {
                seal.reject(PMKError.cancelled)
                return
            }
            wrapping(nil).pipe(to: seal.resolve)
        }
        return promise
    }
}

private final class ImmediateTestSensorProvider: SensorProvider {
    static let uniqueID = "signaled-update-test"
    static var lastCreated: ImmediateTestSensorProvider?

    let request: SensorProviderRequest

    required init(request: SensorProviderRequest) {
        self.request = request
        Self.lastCreated = self
    }

    func sensors() -> Promise<[WebhookSensor]> {
        .value([WebhookSensor(name: "test", uniqueID: Self.uniqueID)])
    }
}

private final class TestSensorUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void

    required init(signal: @escaping () -> Void) {
        self.signal = signal
    }
}
