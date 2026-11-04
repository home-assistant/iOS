import CoreBluetooth
@testable import HomeAssistant
import Improv_iOS
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Drives `ImprovDiscoverView` through the states its manager reports. Bluetooth peripherals can't
/// be created in a test, so the device list stays empty; every other state is rendered.
@MainActor
struct ImprovDiscoverViewTests {
    private final class FakeImprovManager: ImprovManagerProtocol {
        @Published var bluetoothState: CBManagerState = .poweredOff
        @Published var errorState: ErrorState?
        @Published var deviceState: DeviceState?
        @Published var lastResult: [String]?
        @Published var foundDevices: [String: CBPeripheral] = [:]
        @Published var scanInProgress = false
        @Published var connectedDevice: CBPeripheral?
        weak var delegate: ImprovManagerDelegate?

        var scans = 0
        var stops = 0

        func scan() { scans += 1 }
        func stopScan() { stops += 1 }
        func connectToDevice(_ peripheral: CBPeripheral) {}
        func disconnectFromDevice(_ peripheral: CBPeripheral) {}
        func identifyDevice() -> BluetoothManagerError? { nil }
        func sendWifi(ssid: String, password: String) -> BluetoothManagerError? { nil }
        func reset() {}
    }

    private func makeDriver(
        _ manager: FakeImprovManager,
        deviceName: String? = nil
    ) -> SwiftUIScreenDriver {
        SwiftUIScreenDriver(
            ImprovDiscoverView<FakeImprovManager>(
                improvManager: manager,
                deviceName: deviceName,
                redirectRequest: { _ in }
            ),
            size: CGSize(width: 390, height: 844),
            inNavigationStack: false
        )
    }

    /// The flow lives in a sheet, whose updates reach it through the main queue, so this one drives
    /// the screen asynchronously.
    @Test func scansOnceBluetoothIsOnAndStopsWhenDismissed() async {
        let manager = FakeImprovManager()
        manager.bluetoothState = .poweredOn
        let driver = makeDriver(manager)
        defer { driver.close() }
        await #expect(driver.waitUntil { manager.scans >= 1 })

        manager.bluetoothState = .poweredOff
        await driver.settle()
        manager.bluetoothState = .poweredOn
        await #expect(driver.waitUntil { manager.scans >= 2 })

        await driver.dismissPresented()
        await #expect(driver.waitUntil { manager.stops >= 1 })
    }

    /// The flow is a system sheet over a transparent full-screen host: closing the sheet has to take the
    /// host down with it, or an invisible controller would keep blocking the frontend.
    @Test func closingTheSheetDismissesTheHostAndStopsScanning() async {
        let manager = FakeImprovManager()
        manager.bluetoothState = .poweredOn
        let driver = await SwiftUIScreenDriver.show(
            Color.clear,
            size: CGSize(width: 390, height: 844),
            inNavigationStack: false
        )
        defer { driver.close() }

        let host = UIHostingController(rootView: ImprovDiscoverView<FakeImprovManager>(
            improvManager: manager,
            deviceName: nil,
            redirectRequest: { _ in }
        ))
        host.modalPresentationStyle = .overFullScreen
        driver.host.present(host, animated: false)
        await #expect(driver.waitUntil { host.presentedViewController != nil })
        await #expect(driver.waitUntil { manager.scans >= 1 })

        // The close control is the only bar button; on iOS 26 it is a close-role button with no title.
        #expect(driver.barButtons.count == 1)
        await driver.tapBarButton(0)
        await #expect(driver.waitUntil { host.presentingViewController == nil })
        #expect(driver.presented == nil)
        #expect(manager.stops >= 1)
    }

    @Test func rendersEveryDeviceState() {
        let manager = FakeImprovManager()
        let driver = makeDriver(manager)
        defer { driver.close() }

        for state: DeviceState in [.authorizationRequired, .authorized, .provisioning, .provisioned] {
            manager.deviceState = state
            driver.settle()
        }
        manager.lastResult = ["https://example.com/setup?domain=esphome"]
        driver.settle()
        #expect(manager.scans == 0)
    }

    @Test func rendersEveryErrorState() {
        let manager = FakeImprovManager()
        let driver = makeDriver(manager, deviceName: "kitchen-plug")
        defer { driver.close() }

        let errors: [ErrorState] = [
            .invalidRPCPacket,
            .noError,
            .unknownCommand,
            .unableToConnect,
            .notAuthorized,
            .unknown,
        ]
        for error in errors {
            manager.errorState = error
            driver.settle()
        }
        manager.errorState = nil
        driver.settle()
        #expect(manager.errorState == nil)
    }

    @Test func outcomeViewsRender() {
        var tapped = 0
        let success = SwiftUIScreenDriver(ImprovSuccessView { tapped += 1 }, inNavigationStack: false)
        success.close()
        let failure = SwiftUIScreenDriver(
            ImprovFailureView(message: "Unable to connect") { tapped += 1 },
            inNavigationStack: false
        )
        failure.close()
        #expect(tapped == 0)
    }
}
