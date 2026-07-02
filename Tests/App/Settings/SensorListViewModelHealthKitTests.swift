@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Version
import XCTest

class SensorListViewModelHealthKitTests: XCTestCase {
    private var originalHealthKit: AppEnvironment.HealthKit!
    private var previousHealthSensorsEnabled: Any?
    private var previousHealthSensorsHaveBeenEnabled: Any?
    private var previousHealthSensorCache: Any?

    override func setUp() {
        super.setUp()

        originalHealthKit = Current.healthKit
        previousHealthSensorsEnabled = Current.settingsStore.prefs.object(forKey: "healthSensorsEnabled")
        previousHealthSensorsHaveBeenEnabled = Current.settingsStore.prefs
            .object(forKey: "healthSensorsHaveBeenEnabled")
        previousHealthSensorCache = Current.settingsStore.prefs.object(forKey: "healthSensorCache")

        Current.settingsStore.prefs.removeObject(forKey: "healthSensorsEnabled")
        Current.settingsStore.prefs.removeObject(forKey: "healthSensorsHaveBeenEnabled")
        Current.settingsStore.prefs.removeObject(forKey: "healthSensorCache")
        Current.healthKit.isAvailable = { true }
    }

    override func tearDown() {
        restore(previousHealthSensorsEnabled, forKey: "healthSensorsEnabled")
        restore(previousHealthSensorsHaveBeenEnabled, forKey: "healthSensorsHaveBeenEnabled")
        restore(previousHealthSensorCache, forKey: "healthSensorCache")
        Current.healthKit = originalHealthKit
        originalHealthKit = nil
        super.tearDown()
    }

    private func restore(_ value: Any?, forKey key: String) {
        if let value {
            Current.settingsStore.prefs.set(value, forKey: key)
        } else {
            Current.settingsStore.prefs.removeObject(forKey: key)
        }
    }

    func testEnablingHealthSensorsRequestsAuthorizationBeforeEnabling() throws {
        var requested = false
        Current.healthKit.requestReadAuthorization = {
            XCTAssertFalse(Current.settingsStore.healthSensorsEnabled)
            requested = true
            return .value(())
        }
        let viewModel = SensorListViewModel()

        try hang(viewModel.setHealthSensorsEnabled(true))

        XCTAssertTrue(requested)
        XCTAssertTrue(Current.settingsStore.healthSensorsEnabled)
        XCTAssertTrue(viewModel.healthSensorsEnabled)
    }

    func testDisablingHealthSensorsTurnsSettingOffImmediately() throws {
        Current.settingsStore.healthSensorsEnabled = true
        Current.settingsStore.healthSensorCache = .init(
            fetchedAt: Date(),
            values: [.init(metric: .steps, value: 123)]
        )
        var requested = false
        Current.healthKit.requestReadAuthorization = {
            requested = true
            return .value(())
        }
        let viewModel = SensorListViewModel()

        try hang(viewModel.setHealthSensorsEnabled(false))

        XCTAssertFalse(requested)
        XCTAssertFalse(Current.settingsStore.healthSensorsEnabled)
        XCTAssertFalse(viewModel.healthSensorsEnabled)
        XCTAssertNil(Current.settingsStore.healthSensorCache)
    }

    func testUpdateAllSensorsDoesNotEnableHealthSensorsMasterToggle() {
        Current.settingsStore.healthSensorsEnabled = false
        let viewModel = SensorListViewModel()
        viewModel.sensors = [
            WebhookSensor(name: "Health Steps", uniqueID: HealthKitSensor.Metric.steps.uniqueID),
        ]

        viewModel.updateAllSensors(isEnabled: true)

        XCTAssertFalse(Current.settingsStore.healthSensorsEnabled)
        XCTAssertFalse(viewModel.healthSensorsEnabled)
    }
}
