import Foundation
import PromiseKit
@testable import Shared
import Version
import XCTest

class SensorContainerTests: XCTestCase {
    private var observer: MockSensorObserver!
    private var container: SensorContainer!

    private enum TestError: Error {
        case anyError
    }

    override func setUp() {
        super.setUp()

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
        let promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
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

        let promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
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

        let promise1 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result1 = try hang(Promise(promise1))
        XCTAssertEqual(Set(result1.sensors.map(\.Name)), Set([
            "test1a", "test1b",
        ]))

        result1.didPersist()

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

        let promise2 = container.sensors(reason: .registration, serverVersion: Version())
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
        let promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
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

        _ = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        XCTAssertTrue(observer.updates.isEmpty)
    }

    func testEmptySensorsFlowsThrough() throws {
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([]),
            .value([]),
            .value([WebhookSensor(name: "test", uniqueID: "test")]),
        ]

        let promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result = try hang(Promise(promise))
        XCTAssertEqual(result.sensors.map(\.UniqueID), ["test"])
    }

    func testDependenciesInformsUpdate() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(observer: observer)

        MockSensorProvider.returnedPromises = [
            .value([]),
        ]

        let promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
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

        promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1a", "test1b", "test2a", "test2b",
        ]))

        // don't notify about the persisting, it should stay the same
        MockSensorProvider.returnedPromises = initialValues
        promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1a", "test1b", "test2a", "test2b",
        ]))

        // notify, try the same values, nothing should come through
        result.didPersist()
        MockSensorProvider.returnedPromises = initialValues
        promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        result = try hang(Promise(promise))
        XCTAssertTrue(result.sensors.isEmpty)

        // now try a couple changed things, only those should come through
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

        promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map(\.UniqueID)), Set([
            "test1b", "test2c",
        ]))

        // persist again and try again
        result.didPersist()

        // now return nothing, should get nothing
        MockSensorProvider.returnedPromises = [.value([]), .value([])]

        promise = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
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

    func testOutOfOrderCachingValues() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProvider.self)

        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b"),
                WebhookSensor(name: "test1c", uniqueID: "test1c"), // only in first and last one
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b"),
            ]),
        ]

        let promise1 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result1 = try hang(Promise(promise1))
        XCTAssertEqual(Set(result1.sensors.map(\.Name)), Set([
            "test1a", "test1b", "test1c", "test2a", "test2b",
        ]))

        let updatedValues: [Promise<[WebhookSensor]>] = [
            .value([
                WebhookSensor(name: "test1a_mod", uniqueID: "test1a"),
                WebhookSensor(name: "test1b_mod", uniqueID: "test1b"),
            ]),
            .value([
                WebhookSensor(name: "test2a_mod", uniqueID: "test2a"),
                WebhookSensor(name: "test2b_mod", uniqueID: "test2b"),
            ]),
        ]

        MockSensorProvider.returnedPromises = updatedValues

        let promise2 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result2 = try hang(Promise(promise2))
        XCTAssertEqual(Set(result2.sensors.map(\.Name)), Set([
            "test1a_mod", "test1b_mod", "test2a_mod", "test2b_mod",
        ]))

        // complete the later one first
        result2.didPersist()
        // this should _not_ override the 'last persisted' from the newer one
        result1.didPersist()

        MockSensorProvider.returnedPromises = updatedValues

        let promise3 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result3 = try hang(Promise(promise3))
        // we have to assume result1 cleared away what we sent up, so the new values should be the same
        XCTAssertEqual(Set(result3.sensors.map(\.Name)), Set([
            "test1a_mod", "test1b_mod", "test2a_mod", "test2b_mod",
        ]))

        container.register(observer: observer)
        XCTAssertFalse(observer.updates.isEmpty)

        if let last = observer.updates.last?.sensors {
            let observerResult = try hang(Promise(last))
            XCTAssertEqual(Set(observerResult.map(\.Name)), Set([
                "test1a_mod", "test1b_mod", "test1c", "test2a_mod", "test2b_mod",
            ]))
        }

        result3.didPersist()

        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a_mod", uniqueID: "test1a"),
                WebhookSensor(name: "test1b_mod", uniqueID: "test1b"),
                WebhookSensor(name: "test1c", uniqueID: "test1c"), // only in first and last one
            ]),
            .value([
                WebhookSensor(name: "test2a_mod", uniqueID: "test2a"),
                WebhookSensor(name: "test2b_mod", uniqueID: "test2b"),
            ]),
        ]

        let promise4 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result4 = try hang(Promise(promise4))
        // this time we expect nothing new to go up, including the unique one from result1
        XCTAssertTrue(result4.sensors.isEmpty)
    }

    func testChangedFailsButSilentlySucceeded() throws {
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

        let promise1 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result1 = try hang(Promise(promise1))
        XCTAssertEqual(Set(result1.sensors.map(\.Name)), Set([
            "test1a", "test1b", "test2a", "test2b",
        ]))

        result1.didPersist()

        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a_mod", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b"),
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b"),
            ]),
        ]

        let promise2 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result2 = try hang(Promise(promise2))
        XCTAssertEqual(Set(result2.sensors.map(\.Name)), Set([
            "test1a_mod",
        ]))

        // not persisting -- this is e.g. an error case, but the error was silently successful
        // the act of trying to mutate a sensor is going to cause it to need to be re-sent

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

        let promise3 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result3 = try hang(Promise(promise3))
        XCTAssertEqual(Set(result3.sensors.map(\.Name)), Set([
            "test1a",
        ]))
    }

    func testTransientSensorExposedToObservers() throws {
        container.register(provider: MockSensorProvider.self)

        MockSensorProvider.returnedPromises = [.value([
            WebhookSensor(name: "available", uniqueID: "available"),
            WebhookSensor(name: "transient", uniqueID: "transient"),
        ])]
        let promise1 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result1 = try hang(Promise(promise1))
        XCTAssertEqual(Set(result1.sensors.map(\.Name)), Set([
            "available", "transient",
        ]))

        result1.didPersist()

        MockSensorProvider.returnedPromises = [.value([
            WebhookSensor(name: "available", uniqueID: "available"),
            WebhookSensor(name: "transient_changed", uniqueID: "transient"),
        ])]
        let promise2 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result2 = try hang(Promise(promise2))
        XCTAssertEqual(Set(result2.sensors.map(\.Name)), Set([
            "transient_changed",
        ]))

        // not persisting 2 here

        MockSensorProvider.returnedPromises = [.value([
            WebhookSensor(name: "available", uniqueID: "available"),
        ])]
        let promise3 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result3 = try hang(Promise(promise3))
        XCTAssertEqual(Set(result3.sensors.map(\.Name)), Set([]))

        container.register(observer: observer)
        XCTAssertEqual(observer.updates.count, 1)
        let observerSensors = try hang(Promise(XCTUnwrap(observer.updates.last).sensors))
        XCTAssertEqual(observerSensors.map(\.Name), [
            // 'transient' being missing here means that we lost some previous state that was known to be valid
            "available", "transient",
        ])
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
        let promise1 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
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
        let promise2 = container.sensors(reason: .trigger("unit-test"), serverVersion: Version())
        let result2 = try hang(Promise(promise2))
        let result2sensor = try XCTUnwrap(result2.sensors.first)
        XCTAssertEqual(result2sensor, underlying)
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

private class MockUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void
    required init(signal: @escaping () -> Void) {
        self.signal = signal
    }
}
