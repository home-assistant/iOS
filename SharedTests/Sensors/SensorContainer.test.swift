import Foundation
import XCTest
import PromiseKit
@testable import Shared

class SensorContainerTests: XCTestCase {
    private var observer: MockSensorObserver!
    private var container: SensorContainer!

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
}

private class MockSensorObserver: SensorObserver {
    var updates: [(Promise<[WebhookSensor]>, Date)] = []

    func sensorContainer(
        _ container: SensorContainer,
        didUpdate sensors: Promise<[WebhookSensor]>,
        on date: Date
    ) {
        updates.append((sensors, date))
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
