import XCTest
@testable import Shared
import PromiseKit

class SensorProviderDependenciesTests: XCTestCase {
    func testLiveUpdateInfoGivenHandler() {
        let dependencies = SensorProviderDependencies()

        var updateType: SensorProvider.Type?

        dependencies.liveUpdateHandler = { type in
            updateType = type
        }

        let provider = MockSensorProvider1(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil
        ))

        let info: MockLiveUpdateInfo = dependencies.liveUpdateInfo(for: provider)
        XCTAssertNil(updateType)

        info.notify()
        XCTAssertTrue(updateType == MockSensorProvider1.self)
    }

    func testLiveUpdateInfoCachesExisting() {
        let dependencies = SensorProviderDependencies()

        let provider1 = MockSensorProvider1(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil
        ))
        let provider2 = MockSensorProvider1(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil
        ))

        let info1: MockLiveUpdateInfo = dependencies.liveUpdateInfo(for: provider1)
        let info2: MockLiveUpdateInfo = dependencies.liveUpdateInfo(for: provider2)
        XCTAssertTrue(info1 === info2)
    }

    func testLiveUpdateInfoNotSharedAcrossProviders() {
        let dependencies = SensorProviderDependencies()

        let provider1 = MockSensorProvider1(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil
        ))
        let provider2 = MockSensorProvider2(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil
        ))

        let info1_1: MockLiveUpdateInfo = dependencies.liveUpdateInfo(for: provider1)
        let info1_2: MockLiveUpdateInfo = dependencies.liveUpdateInfo(for: provider1)
        let info2_1: MockLiveUpdateInfo = dependencies.liveUpdateInfo(for: provider2)
        let info2_2: MockLiveUpdateInfo = dependencies.liveUpdateInfo(for: provider2)
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

private class MockLiveUpdateInfo: SensorProviderLiveUpdateInfo {
    let notify: () -> Void
    required init(notifying: @escaping () -> Void) {
        self.notify = notifying
    }
}
