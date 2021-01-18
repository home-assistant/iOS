import Foundation
import XCTest
import PromiseKit
@testable import Shared

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

    func testMultipleProvidersFlattensAndNotifies() throws {
        container.register(observer: observer)
        container.register(provider: MockSensorProvider.self)
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b")
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b")
            ])
        ]

        let date = Date()
        Current.date = { date }
        let promise = container.sensors(reason: .trigger("unit-test"))
        let result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map { $0.UniqueID }), Set([
            "test1a", "test1b", "test2a", "test2b"
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
                WebhookSensor(name: "test1b", uniqueID: "test1b")
            ])
        ]

        let promise = container.sensors(reason: .trigger("unit-test"))
        let result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map { $0.UniqueID }), Set([
            "test1a", "test1b"
        ]))
    }

    func testRegistrationDoesntCache() throws {
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b")
            ])
        ]

        let promise = container.sensors(reason: .registration)
        let result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map { $0.UniqueID }), Set([
            "test1a", "test1b"
        ]))

        container.register(observer: observer)
        XCTAssertTrue(observer.updates.isEmpty)
    }

    func testTriggerDoesCache() throws {
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b", uniqueID: "test1b")
            ])
        ]

        let date = Date(timeIntervalSinceNow: -200)
        Current.date = { date }
        let promise = container.sensors(reason: .trigger("unit-test"))
        let result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map { $0.UniqueID }), Set([
            "test1a", "test1b"
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
            .value([ WebhookSensor(name: "test", uniqueID: "test") ])
        ]

        _ = container.sensors(reason: .trigger("unit-test"))
        XCTAssertTrue(observer.updates.isEmpty)
    }

    func testEmptySensorsFlowsThrough() throws {
        container.register(provider: MockSensorProvider.self)
        MockSensorProvider.returnedPromises = [
            .value([]),
            .value([]),
            .value([ WebhookSensor(name: "test", uniqueID: "test") ])
        ]

        let promise = container.sensors(reason: .trigger("unit-test"))
        let result = try hang(Promise(promise))
        XCTAssertEqual(result.sensors.map { $0.UniqueID }, [ "test" ])
    }

    func testDependenciesInformsUpdate() throws {
        container.register(provider: MockSensorProvider.self)
        container.register(observer: observer)

        MockSensorProvider.returnedPromises = [
            .value([]),
        ]

        let promise = container.sensors(reason: .trigger("unit-test"))
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
                WebhookSensor(name: "test1b", uniqueID: "test1b")
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b")
            ])
        ]

        MockSensorProvider.returnedPromises = initialValues

        var promise: Guarantee<SensorResponse>
        var result: SensorResponse

        promise = container.sensors(reason: .trigger("unit-test"))
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map { $0.UniqueID }), Set([
            "test1a", "test1b", "test2a", "test2b"
        ]))

        // don't notify about the persisting, it should stay the same
        MockSensorProvider.returnedPromises = initialValues
        promise = container.sensors(reason: .trigger("unit-test"))
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map { $0.UniqueID }), Set([
            "test1a", "test1b", "test2a", "test2b"
        ]))

        // notify, try the same values, nothing should come through
        result.didPersist()
        MockSensorProvider.returnedPromises = initialValues
        promise = container.sensors(reason: .trigger("unit-test"))
        result = try hang(Promise(promise))
        XCTAssertTrue(result.sensors.isEmpty)

        // now try a couple changed things, only those should come through
        MockSensorProvider.returnedPromises = [
            .value([
                WebhookSensor(name: "test1a", uniqueID: "test1a"),
                WebhookSensor(name: "test1b-mod", uniqueID: "test1b")
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b"),
                WebhookSensor(name: "test2c-new", uniqueID: "test2c")
            ])
        ]

        promise = container.sensors(reason: .trigger("unit-test"))
        result = try hang(Promise(promise))
        XCTAssertEqual(Set(result.sensors.map { $0.UniqueID }), Set([
            "test1b", "test2c"
        ]))

        // persist again and try again
        result.didPersist()

        // now return nothing, should get nothing
        MockSensorProvider.returnedPromises = [.value([]), .value([])]

        promise = container.sensors(reason: .trigger("unit-test"))
        result = try hang(Promise(promise))
        XCTAssertTrue(result.sensors.isEmpty)

        // now let's see what the current 'last update' state is
        container.register(observer: observer)
        XCTAssertFalse(observer.updates.isEmpty)

        if let last = observer.updates.last?.sensors {
            let observerResult = try hang(Promise(last))
            XCTAssertEqual(Set(observerResult.map { $0.UniqueID }), Set([
                "test1a", "test1b", "test2a", "test2b", "test2c"
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
                WebhookSensor(name: "test1c", uniqueID: "test1c") // only in first one
            ]),
            .value([
                WebhookSensor(name: "test2a", uniqueID: "test2a"),
                WebhookSensor(name: "test2b", uniqueID: "test2b")
            ])
        ]

        let promise1 = container.sensors(reason: .trigger("unit-test"))
        let result1 = try hang(Promise(promise1))
        XCTAssertEqual(Set(result1.sensors.map { $0.Name }), Set([
            "test1a", "test1b", "test1c", "test2a", "test2b"
        ]))

        let updatedValues: [Promise<[WebhookSensor]>] = [
            .value([
                WebhookSensor(name: "test1a_mod", uniqueID: "test1a"),
                WebhookSensor(name: "test1b_mod", uniqueID: "test1b")
            ]),
            .value([
                WebhookSensor(name: "test2a_mod", uniqueID: "test2a"),
                WebhookSensor(name: "test2b_mod", uniqueID: "test2b")
            ])
        ]

        MockSensorProvider.returnedPromises = updatedValues

        let promise2 = container.sensors(reason: .trigger("unit-test"))
        let result2 = try hang(Promise(promise2))
        XCTAssertEqual(Set(result2.sensors.map { $0.Name }), Set([
            "test1a_mod", "test1b_mod", "test2a_mod", "test2b_mod"
        ]))

        // complete the later one first
        result2.didPersist()
        // this should _not_ override the 'last persisted' from the newer one
        result1.didPersist()

        MockSensorProvider.returnedPromises = updatedValues

        let promise3 = container.sensors(reason: .trigger("unit-test"))
        let result3 = try hang(Promise(promise3))
        XCTAssertTrue(result3.sensors.isEmpty)

        container.register(observer: observer)
        XCTAssertFalse(observer.updates.isEmpty)

        if let last = observer.updates.last?.sensors {
            let observerResult = try hang(Promise(last))
            XCTAssertEqual(Set(observerResult.map { $0.Name }), Set([
                "test1a_mod", "test1b_mod", "test1c", "test2a_mod", "test2b_mod"
            ]))
        }

        result2.didPersist()
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

    func sensorContainerDidSignalForUpdate(_ container: SensorContainer) {
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
        return returnedPromise
    }
}

private class MockUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void
    required init(signal: @escaping () -> Void) {
        self.signal = signal
    }
}
