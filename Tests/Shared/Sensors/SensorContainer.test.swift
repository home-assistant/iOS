import Foundation
import PromiseKit
@testable import Shared
import Version
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

        observer = MockSensorObserver()
        container = SensorContainer()
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

    func sensorContainer(_ container: SensorContainer, didSignalForUpdateBecause reason: SensorContainerUpdateReason) {
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
