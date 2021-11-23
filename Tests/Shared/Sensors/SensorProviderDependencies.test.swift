import PromiseKit
@testable import Shared
import Version
import XCTest

class SensorProviderDependenciesTests: XCTestCase {
    func testUpdateSignalerGivenHandler() {
        let dependencies = SensorProviderDependencies()

        var updateType: SensorProvider.Type?

        dependencies.updateSignalHandler = { type in
            updateType = type
        }

        let provider = MockSensorProvider1(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))

        let info: MockUpdateSignaler = dependencies.updateSignaler(for: provider)
        XCTAssertNil(updateType)

        info.signal()
        XCTAssertTrue(updateType == MockSensorProvider1.self)
    }

    func testUpdateSignalerCachesExisting() {
        let dependencies = SensorProviderDependencies()

        let provider1 = MockSensorProvider1(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        let provider2 = MockSensorProvider1(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))

        let info1: MockUpdateSignaler = dependencies.updateSignaler(for: provider1)
        let info2: MockUpdateSignaler = dependencies.updateSignaler(for: provider2)
        XCTAssertTrue(info1 === info2)
    }

    func testUpdateSignalerNotSharedAcrossProviders() {
        let dependencies = SensorProviderDependencies()

        let provider1 = MockSensorProvider1(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        let provider2 = MockSensorProvider2(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))

        let info1_1: MockUpdateSignaler = dependencies.updateSignaler(for: provider1)
        let info1_2: MockUpdateSignaler = dependencies.updateSignaler(for: provider1)
        let info2_1: MockUpdateSignaler = dependencies.updateSignaler(for: provider2)
        let info2_2: MockUpdateSignaler = dependencies.updateSignaler(for: provider2)
        XCTAssertTrue(info1_1 !== info2_1)
        XCTAssertTrue(info1_1 === info1_2)

        XCTAssertTrue(info1_2 !== info2_2)
        XCTAssertTrue(info2_1 === info2_2)
    }
}

private class MockSensorProvider1: SensorProvider {
    required init(request: SensorProviderRequest) {}
    func sensors() -> Promise<[WebhookSensor]> { fatalError() }
}

private class MockSensorProvider2: SensorProvider {
    required init(request: SensorProviderRequest) {}
    func sensors() -> Promise<[WebhookSensor]> { fatalError() }
}

private class MockUpdateSignaler: SensorProviderUpdateSignaler {
    let signal: () -> Void
    required init(signal: @escaping () -> Void) {
        self.signal = signal
    }
}
