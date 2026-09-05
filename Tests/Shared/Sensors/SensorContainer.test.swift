import Foundation
import ObjectMapper
import PromiseKit
@testable import Shared
import XCTest

class SensorContainerTests: XCTestCase {
    private var observer: MockSensorObserver!
    private var container: SensorContainer!
    private var server1: Server!
    private var server2: Server!

    private enum TestError: Error {
        case anyError
    }

    override func setUp() {
        super.setUp()

        let servers = FakeServerManager()
        server1 = servers.addFake()
        server2 = servers.addFake()
        Current.servers = servers

        SensorEnablementStore.resetForTesting()
        observer = MockSensorObserver()
        container = SensorContainer()
    }

    override func tearDown() {
        super.tearDown()

        SensorEnablementStore.resetForTesting()
    }

    func testNoProvidersNoCachedDoesntNotify() {
        XCTAssertTrue(observer.updates.isEmpty)
        container.register(observer: observer)
        XCTAssertTrue(observer.updates.isEmpty)
    }

    func testInitialRegistrationOfProvider() throws {
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
            ]),
        ]
        container.register(provider: MockSensorProvider.self)

        container.register(observer: observer)
        XCTAssertEqual(observer.updates.count, 0)
    }

    func testMultipleProvidersFlattensAndNotifies() throws {
        container.register(observer: observer)
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b"),
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b"),
            ]),
        ]

        let date = Date()
        Current.date = { date }
        let promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        let result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1a", "test1b", "test2a", "test2b",
        ]))
        XCTAssertEqual(observer.updates.count, 1)
        if let update = observer.updates.first {
            let updateResult = try hang(Promise(update.sensors))
            XCTAssertEqual(
                updateResult.map(\.asTestEquatableForSensorContainer),
                result.sensors.sorted().map(\.asTestEquatableForSensorContainer)
            )
            XCTAssertEqual(update.on, date)
        }
    }

    /// The list the user sees comes from this update, and a row that jumped as it was switched on
    /// would move the next one under their finger.
    func testUpdateIsAlphabeticalWhicheverSensorsAreEnabled() throws {
        container.register(observer: observer)
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "Charlie", uniqueID: "charlie"),
                WebhookSensor(name: "alpha", uniqueID: "alpha"),
                WebhookSensor(name: "Bravo", uniqueID: "bravo"),
            ]),
        ]
        container.setEnabled(true, forUniqueID: "charlie")

        _ = try hang(Promise(container.sensors(reason: .trigger("unit-test"), server: server1)))

        let update = try XCTUnwrap(observer.updates.first)
        let names = try hang(Promise(update.sensors)).map { $0.Name ?? "" }
        XCTAssertEqual(names, ["alpha", "Bravo", "Charlie"])
    }

    func testMultipleButContainingErrorsReturnsSuccessful() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            Promise(error: TestError.anyError),
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b"),
            ]),
        ]

        let promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        let result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1a", "test1b",
        ]))
    }

    func testRegistrationDoesntOverrideCache() throws {
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b"),
            ]),
        ]

        let date1 = Date(timeIntervalSinceNow: -200)
        Current.date = { date1 }

        let promise1 = container.sensors(reason: .trigger("unit-test"), server: server1)
        let result1 = try hang(Promise(promise1))
        XCTAssertEqual(Set(result1.sensors.map(\.Name)), Set([
            "test1a", "test1b",
        ]))

        container.register(observer: observer)
        XCTAssertEqual(observer.updates.count, 1)
        if let update = observer.updates.first {
            let updateResult = try hang(Promise(update.sensors))
            XCTAssertEqual(
                updateResult.map(\.asTestEquatableForSensorContainer),
                result1.sensors.map(\.asTestEquatableForSensorContainer)
            )
            XCTAssertEqual(update.on, date1)
        }

        let date2 = Date(timeIntervalSinceNow: -100)
        Current.date = { date2 }

        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"), // same
                WebhookSensor(name: "test1b_mod", uniqueID: "test1b"), // changed value, ignored for cache
                WebhookSensor(name: "test1c", uniqueID: "test1c"), // new sensor
            ]),
        ]

        let promise2 = container.sensors(reason: .registration, server: server1)
        let result2 = try hang(Promise(promise2))

        // registration doesn't do any filtering
        XCTAssertEqual(Set(result2.sensors.map(\.Name)), Set([
            "test1a", "test1b_mod", "test1c",
        ]))

        XCTAssertEqual(observer.updates.count, 2)
        if observer.updates.count > 1 {
            let update = observer.updates[1]
            let updateResult = try hang(Promise(update.sensors))
            XCTAssertEqual(
                updateResult.map(\.Name),
                ["test1a", "test1b", "test1c"]
            )
            XCTAssertEqual(update.on, date2)
        }
    }

    func testTriggerDoesCache() throws {
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b"),
            ]),
        ]

        let date = Date(timeIntervalSinceNow: -200)
        Current.date = { date }
        let promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        let result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1a", "test1b",
        ]))

        container.register(observer: observer)
        XCTAssertEqual(observer.updates.count, 1)
        if let update = observer.updates.first {
            let updateResult = try hang(Promise(update.sensors))
            XCTAssertEqual(
                updateResult.map(\.asTestEquatableForSensorContainer),
                result.sensors.map(\.asTestEquatableForSensorContainer)
            )
            XCTAssertEqual(update.on, date)
        }
    }

    func testUnregisteredObserverIsntNotified() {
        container.register(observer: observer)
        container.unregister(observer: observer)
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([WebhookSensor(name: "test", uniqueID: "test")]),
        ]

        _ = container.sensors(reason: .trigger("unit-test"), server: server1)
        XCTAssertTrue(observer.updates.isEmpty)
    }

    func testEmptySensorsFlowsThrough() throws {
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([]),
            .value([]),
            .value([WebhookSensor(name: "test", uniqueID: "test")]),
        ]

        let promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        let result = try hang(Promise(promise))
        XCTAssertEqual(result.sensors.map(\.UniqueID), ["test"])
    }

    func testDependenciesInformsUpdate() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(observer: observer)

        MockSensorProvider.returnedPromises = [
            .value([]),
        ]

        let promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        _ = try hang(Promise(promise))

        guard let lastCreated = MockSensorProvider.lastCreated else {
            XCTFail("expected a provider to have been created")
            return
        }

        XCTAssertEqual(observer.updateSignalCount, 0)

        let info: MockUpdateSignaler = lastCreated
            .request
            .dependencies
            .updateSignaler(for: lastCreated)
        info.signal()

        XCTAssertEqual(observer.updateSignalCount, 1)
    }

    func testCachingSensorValues() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProvider.self)

        let initialValues: [Promise<[WebhookSensor]>] = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b"),
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b"),
            ]),
        ]

        MockSensorProvider.returnedPromises = initialValues

        var promise: Guarantee<SensorResponse>
        var result: SensorResponse

        promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1a", "test1b", "test2a", "test2b",
        ]))

        MockSensorProvider.returnedPromises = initialValues
        promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1a", "test1b", "test2a", "test2b",
        ]))

        // now try a couple changed things
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b-mod", uniqueID: "test1b"),
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b"),
                WebhookSensor(name: "test2c-new", uniqueID: "test2c"),
            ]),
        ]

        promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1a", "test1b", "test2a", "test2b", "test2c",
        ]))

        // now return nothing, should get nothing
        MockSensorProvider.returnedPromises = [.value([]), .value([])]

        promise = container.sensors(reason: .trigger("unit-test"), server: server1)
        result = try hang(Promise(promise))
        XCTAssertTrue(result.sensors.isEmpty)

        // now let's see what the current 'last update' state is
        container.register(observer: observer)
        XCTAssertFalse(observer.updates.isEmpty)

        if let last = observer.updates.last?.sensors {
            let observerResult = try hang(Promise(last))
            XCTAssertEqual(Set(observerResult.map(\.UniqueID)), Set([
                "test1a", "test1b", "test2a", "test2b", "test2c",
            ]))
        }
    }

    func testDisabledSensorRedacted() throws {
        container.register(provider: MockSensorProvider.self)

        let underlying = with(WebhookSensor(name: "test1a", uniqueID: "testDisabled")) {
            $0.State = "state"
            $0.Attributes = ["test": true]
        }
        container.setEnabled(false, for: underlying)
        XCTAssertFalse(container.isEnabled(sensor: underlying))

        let promises: [Promise<[WebhookSensor]>] = [.value([underlying])]

        MockSensorProvider.returnedPromises = promises
        let promise1 = container.sensors(reason: .trigger("unit-test"), server: server1)
        let result1 = try hang(Promise(promise1))

        let result1sensor = try XCTUnwrap(result1.sensors.first)
        XCTAssertEqual(result1sensor.UniqueID, underlying.UniqueID)
        XCTAssertEqual(result1sensor.State as? String, "unavailable")
        XCTAssertNil(result1sensor.Attributes)
        XCTAssertEqual(result1sensor.Name, underlying.Name)
        XCTAssertEqual(result1sensor.Icon, "mdi:dots-square")

        container.setEnabled(true, for: underlying)
        XCTAssertTrue(container.isEnabled(sensor: underlying))

        MockSensorProvider.returnedPromises = promises
        let promise2 = container.sensors(reason: .trigger("unit-test"), server: server1)
        let result2 = try hang(Promise(promise2))
        let result2sensor = try XCTUnwrap(result2.sensors.first)
        XCTAssertEqual(result2sensor, underlying)
    }

    func testDisabledServersRedacted() throws {
        container.register(provider: MockSensorProvider.self)

        let underlying = with(WebhookSensor(name: "test1a", uniqueID: "testDisabled")) {
            $0.State = "state"
            $0.Attributes = ["test": true]
        }

        server1.info.setSetting(value: ServerSensorPrivacy.none, for: .sensorPrivacy)

        MockSensorProvider.returnedPromises = [.value([underlying])]
        let promiseS1 = container.sensors(reason: .trigger("unit-test"), server: server1)
        let resultS1 = try hang(Promise(promiseS1))

        MockSensorProvider.returnedPromises = [.value([underlying])]
        let promiseS2 = container.sensors(reason: .trigger("unit-test"), server: server2)
        let resultS2 = try hang(Promise(promiseS2))

        let sensorS1 = try XCTUnwrap(resultS1.sensors.first)
        XCTAssertEqual(sensorS1.UniqueID, underlying.UniqueID)
        XCTAssertEqual(sensorS1.State as? String, "unavailable")
        XCTAssertNil(sensorS1.Attributes)
        XCTAssertEqual(sensorS1.Name, underlying.Name)
        XCTAssertEqual(sensorS1.Icon, "mdi:dots-square")

        let sensorS2 = try XCTUnwrap(resultS2.sensors.first)
        XCTAssertEqual(sensorS2.UniqueID, underlying.UniqueID)
        XCTAssertEqual(sensorS2.State as? String, "state")
        XCTAssertEqual(sensorS2.Attributes?["test"] as? Bool, true)
        XCTAssertEqual(sensorS2.Name, underlying.Name)
    }

    func testRegistrationCarriesEnablement() throws {
        container.register(provider: MockSensorProvider.self)

        let underlying = WebhookSensor(name: "test1a", uniqueID: "testEnablement")
        container.setEnabled(false, for: underlying)

        MockSensorProvider.returnedPromises = [.value([underlying])]
        let disabled = try hang(Promise(container.sensors(reason: .registration, server: server1)))
        let disabledSensor = try XCTUnwrap(disabled.sensors.first)
        XCTAssertEqual(disabledSensor.Disabled, true)
        XCTAssertEqual(disabledSensor.toJSON()["disabled"] as? Bool, true)

        container.setEnabled(true, for: underlying)

        MockSensorProvider.returnedPromises = [.value([underlying])]
        let enabled = try hang(Promise(container.sensors(reason: .registration, server: server1)))
        XCTAssertEqual(try XCTUnwrap(enabled.sensors.first).Disabled, false)
    }

    func testStateUpdateOmitsEnablement() throws {
        container.register(provider: MockSensorProvider.self)

        let underlying = WebhookSensor(name: "test1a", uniqueID: "testEnablementOmitted")
        container.setEnabled(false, for: underlying)

        MockSensorProvider.returnedPromises = [.value([underlying])]
        let result = try hang(Promise(container.sensors(reason: .trigger("unit-test"), server: server1)))
        let sensor = try XCTUnwrap(result.sensors.first)
        XCTAssertNil(sensor.Disabled)

        let updateJSON = Mapper<WebhookSensor>(context: WebhookSensorContext(update: true)).toJSON(sensor)
        XCTAssertNil(updateJSON["disabled"])
    }

    /// A slow run must not overwrite a value that a later run read — and reported — while it was
    /// still waiting on its other providers, which is how switching Focus got logged in Home
    /// Assistant as `Work → (blank) → Work`.
    func testValueReadBeforeOneAlreadySentIsReplaced() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProvider.self)
        // Opt-in like every sensor, and this test is about the value that reaches the server.
        container.setEnabled(true, forUniqueID: "focus_name")

        let (slowProvider, slowSeal) = Promise<[WebhookSensor]>.pending()

        // The slow run reads the focus name before the switch, then stalls on its other provider.
        // `returnedPromises` is popped from the end, so the stalling one is listed first.
        MockSensorProvider.returnedPromises = [
            slowProvider,
            .value([WebhookSensor(name: "Focus name", uniqueID: "focus_name", state: "")]),
        ]
        let slowRun = container.sensors(reason: .trigger("battery"), server: server1)

        // The switch happens, and a run limited to the focus sensors overtakes it.
        MockSensorProvider.returnedPromises = [
            .value([]),
            .value([WebhookSensor(name: "Focus name", uniqueID: "focus_name", state: "Work")]),
        ]
        let fastRun = container.sensors(reason: .trigger("focus-filter"), server: server1)

        let fastResult = try hang(Promise(fastRun))
        XCTAssertEqual(fastResult.sensors.map(\.UniqueID), ["focus_name"])
        XCTAssertEqual(fastResult.sensors.first?.State as? String, "Work")

        // Only now does the slow run finish, still carrying the name it read before the switch.
        slowSeal.fulfill([WebhookSensor(name: "slow", uniqueID: "slow")])
        let slowResult = try hang(Promise(slowRun))
        XCTAssertEqual(Set(slowResult.sensors.map(\.UniqueID)), Set(["focus_name", "slow"]))
        XCTAssertEqual(
            slowResult.sensors.first(where: { $0.UniqueID == "focus_name" })?.State as? String,
            "Work",
            "the pre-switch focus name must not be sent after the post-switch one"
        )
    }

    /// The same run, but the server that got the newer value isn't the one now being sent to.
    func testValueSentToOneServerDoesntStopAnother() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProvider.self)
        container.setEnabled(true, forUniqueID: "focus_name")

        let (slowProvider, slowSeal) = Promise<[WebhookSensor]>.pending()

        MockSensorProvider.returnedPromises = [
            slowProvider,
            .value([WebhookSensor(name: "Focus name", uniqueID: "focus_name", state: "")]),
        ]
        let slowRun = container.sensors(reason: .trigger("battery"), server: server2)

        MockSensorProvider.returnedPromises = [
            .value([]),
            .value([WebhookSensor(name: "Focus name", uniqueID: "focus_name", state: "Work")]),
        ]
        _ = try hang(Promise(container.sensors(reason: .trigger("focus-filter"), server: server1)))

        slowSeal.fulfill([WebhookSensor(name: "slow", uniqueID: "slow")])
        let slowResult = try hang(Promise(slowRun))
        XCTAssertEqual(Set(slowResult.sensors.map(\.UniqueID)), Set(["focus_name", "slow"]))
        XCTAssertEqual(
            slowResult.sensors.first(where: { $0.UniqueID == "focus_name" })?.State as? String,
            "",
            "server2 never got the newer value, so it still gets what this run read"
        )
    }

    /// Registration describes the whole sensor set, so an entity whose value another run has since
    /// sent must still appear in the payload that creates it.
    func testRegistrationKeepsSensorsAlreadySent() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProvider.self)

        let (slowProvider, slowSeal) = Promise<[WebhookSensor]>.pending()

        MockSensorProvider.returnedPromises = [
            slowProvider,
            .value([WebhookSensor(name: "Focus name", uniqueID: "focus_name", state: "")]),
        ]
        let registrationRun = container.sensors(reason: .registration, server: server1)

        MockSensorProvider.returnedPromises = [
            .value([]),
            .value([WebhookSensor(name: "Focus name", uniqueID: "focus_name", state: "Work")]),
        ]
        _ = try hang(Promise(container.sensors(reason: .trigger("focus-filter"), server: server1)))

        slowSeal.fulfill([WebhookSensor(name: "slow", uniqueID: "slow")])
        let registration = try hang(Promise(registrationRun))
        XCTAssertEqual(Set(registration.sensors.map(\.UniqueID)), Set(["focus_name", "slow"]))
    }

    func testSensorsLimitedTo() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProviderLimitedTo.self)

        let expected = WebhookSensor(name: "included", uniqueID: "included")
        let promises: [Promise<[WebhookSensor]>] = [.value([expected])]

        MockSensorProvider.returnedPromises = promises

        let promise = container.sensors(
            reason: .registration,
            limitedTo: [MockSensorProvider.self],
            location: nil,
            server: server1
        )
        let result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set(["included"]))
    }
}

private extension WebhookSensor {
    var asTestEquatableForSensorContainer: [String] {
        [UniqueID ?? "missing", Name ?? "missing"]
    }
}

private class MockSensorObserver: SensorObserver {
    var updates: [SensorObserverUpdate] = []
    var updateSignalCount: Int = 0

    func sensorContainer(
        _ container: SensorContainer,
        didUpdate update: SensorObserverUpdate
    ) {
        updates.append(update)
    }

    func sensorContainer(
        _ container: SensorContainer,
        didSignalForUpdateBecause reason: SensorContainerUpdateReason,
        lastUpdate: SensorObserverUpdate?
    ) {
        updateSignalCount += 1
    }
}

private class MockSensorProvider: SensorProvider {
    static var returnedPromises: [Promise<[WebhookSensor]>] = []
    static var lastCreated: MockSensorProvider?

    let request: SensorProviderRequest
    let returnedPromise: Promise<[WebhookSensor]>
    required init(request: SensorProviderRequest) {
        self.request = request
        self.returnedPromise = Self.returnedPromises.popLast() ?? .init(error: InvalidTest.noPromiseProvided)
        Self.lastCreated = self
    }

    enum InvalidTest: Error {
        case noPromiseProvided
    }

    func sensors() -> Promise<[WebhookSensor]> {
        returnedPromise
    }
}

private class MockSensorProviderLimitedTo: SensorProvider {
    required init(request: SensorProviderRequest) {
        //
    }

    func sensors() -> Promise<[WebhookSensor]> {
        XCTFail("expected to not be called")
        return .value([])
    }
}

private class MockUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void
    required init(signal: @escaping () -> Void) {
        self.signal = signal
    }
}
