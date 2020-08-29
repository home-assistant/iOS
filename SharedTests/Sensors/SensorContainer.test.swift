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
        XCTAssertEqual(Set(result.map { $0.UniqueID }), Set([
            "test1a", "test1b", "test2a", "test2b"
        ]))
        XCTAssertEqual(observer.updates.count, 1)
        if let update = observer.updates.first {
            let updateResult = try hang(Promise(update.sensors))
            XCTAssertEqual(
                updateResult.map(\.asTestEquatableForSensorContainer),
                result.map(\.asTestEquatableForSensorContainer)
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
        XCTAssertEqual(Set(result.map { $0.UniqueID }), Set([
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
        XCTAssertEqual(Set(result.map { $0.UniqueID }), Set([
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
        XCTAssertEqual(Set(result.map { $0.UniqueID }), Set([
            "test1a", "test1b"
        ]))

        container.register(observer: observer)
        XCTAssertEqual(observer.updates.count, 1)
        if let update = observer.updates.first {
            let updateResult = try hang(Promise(update.sensors))
            XCTAssertEqual(
                updateResult.map(\.asTestEquatableForSensorContainer),
                result.map(\.asTestEquatableForSensorContainer)
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
        XCTAssertEqual(result.map { $0.UniqueID }, [ "test" ])
    }
}

private extension WebhookSensor {
    var asTestEquatableForSensorContainer: [String] {
        [UniqueID ?? "missing", Name ?? "missing"]
    }
}

private class MockSensorObserver: SensorObserver {
    func sensorContainerRequestsUpdate(_ container: SensorContainer) {
        
    }

    var updates: [SensorObserverUpdate] = []

    func sensorContainer(
        _ container: SensorContainer,
        didUpdate update: SensorObserverUpdate
    ) {
        updates.append(update)
    }
}

private class MockSensorProvider: SensorProvider {
    static var returnedPromises: [Promise<[WebhookSensor]>] = []

    let request: SensorProviderRequest
    let returnedPromise: Promise<[WebhookSensor]>
    required init(request: SensorProviderRequest) {
        self.request = request
        self.returnedPromise = Self.returnedPromises.popLast() ?? .init(error: InvalidTest.noPromiseProvided)
    }

    enum InvalidTest: Error {
        case noPromiseProvided
    }

    func sensors() -> Promise<[WebhookSensor]> {
        return returnedPromise
    }
}

