#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@testable import Shared
import UIKit
import XCTest

/// The default closures of a fresh `DeviceWrapper` read straight from the system.
final class DeviceWrapperTests: XCTestCase {
    private var previousIsCatalyst = false

    override func setUp() {
        super.setUp()
        previousIsCatalyst = Current.isCatalyst
        Current.isCatalyst = false
    }

    override func tearDown() {
        Current.isCatalyst = previousIsCatalyst
        super.tearDown()
    }

    func testDeviceDescriptionComesFromUIDevice() {
        let device = DeviceWrapper()

        XCTAssertEqual(device.identifierForVendor(), UIDevice.current.identifierForVendor?.uuidString)
        XCTAssertEqual(device.inspecificModel(), UIDevice.current.model)
        XCTAssertEqual(device.deviceName(), UIDevice.current.name)
        XCTAssertEqual(device.systemName(), UIDevice.current.systemName)
        XCTAssertEqual(device.systemVersion(), UIDevice.current.systemVersion)
        XCTAssertEqual(device.isLowPowerMode(), ProcessInfo.processInfo.isLowPowerModeEnabled)
        XCTAssertNil(device.idleTime())
        XCTAssertNil(device.screens())
    }

    func testSystemModelIsTheMachineIdentifier() {
        let device = DeviceWrapper()

        let model = device.systemModel()

        XCTAssertFalse(model.isEmpty)
        XCTAssertFalse(model.contains("\0"))
    }

    func testCatalystReportsTheOperatingSystemVersionAndHardwareModel() {
        Current.isCatalyst = true
        let device = DeviceWrapper()

        let version = ProcessInfo.processInfo.operatingSystemVersion
        XCTAssertEqual(
            device.systemVersion(),
            "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        )
        XCTAssertFalse(device.systemModel().isEmpty)
    }

    func testVolumesReportCapacities() throws {
        let volumes = try XCTUnwrap(DeviceWrapper().volumes())

        let total = try XCTUnwrap(volumes[.volumeTotalCapacityKey])
        XCTAssertGreaterThan(total, 0)
        for value in volumes.values {
            XCTAssertGreaterThanOrEqual(value, 0)
        }
    }

    func testBatteriesDescribeTheDevice() {
        let batteries = DeviceWrapper().batteries()

        XCTAssertEqual(batteries.count, 1)
    }

    func testBatteryStateChangesReachRegisteredObservers() {
        let center = DeviceWrapperBatteryNotificationCenter()
        let observer = BatteryObserver()
        let unregistered = BatteryObserver()
        center.register(observer: observer)
        center.register(observer: unregistered)
        center.unregister(observer: unregistered)

        NotificationCenter.default.post(name: UIDevice.batteryStateDidChangeNotification, object: nil)

        XCTAssertEqual(observer.changeCount, 1)
        XCTAssertEqual(unregistered.changeCount, 0)
        XCTAssertTrue(UIDevice.current.isBatteryMonitoringEnabled)
    }

    func testLazyBatteryNotificationCenterIsReused() {
        let device = DeviceWrapper()

        XCTAssertTrue(device.batteryNotificationCenter === device.batteryNotificationCenter)
    }

    private final class BatteryObserver: DeviceWrapperBatteryNotificationObserver {
        var changeCount = 0

        func deviceBatteryStateDidChange(_ center: DeviceWrapperBatteryNotificationCenter) {
            changeCount += 1
        }
    }
}
#endif
