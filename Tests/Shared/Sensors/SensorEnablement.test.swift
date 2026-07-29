import Foundation
import PromiseKit
@testable import Shared
import XCTest

class SensorEnablementTests: XCTestCase {
    private var container: SensorContainer!
    private var server: Server!

    /// A battery whose unique ID comes from the hardware, so it can't be known ahead of time.
    private let dynamicSensorID = "battery-serial-1234_level"

    override func setUp() {
        super.setUp()

        let servers = FakeServerManager()
        server = servers.addFake()
        Current.servers = servers

        SensorEnablementStore.resetForTesting()
        container = SensorContainer()
    }

    override func tearDown() {
        super.tearDown()

        SensorEnablementStore.resetForTesting()
    }

    // MARK: - Migrating an install that predates the allowlist

    func testUpgradeKeepsSensorsTheUserHadNotDisabled() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [WebhookSensorId.storage.rawValue])

        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue))
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue))
        XCTAssertTrue(container.isEnabled(uniqueID: HealthKitSensor.Metric.steps.uniqueID))
    }

    func testUpgradeLeavesOptInSensorsOffWhenTheDeviceNeverProducedThem() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        // Absent from the denylist only because this device never ran them, not because the user
        // asked for them.
        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.cameraMotion.rawValue))
        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.cameraStream.rawValue))
    }

    func testUpgradeKeepsOptInSensorsTheUserHadTurnedOn() {
        SensorEnablementStore.seedLegacyStateForTesting(
            disabledSensorIDs: [],
            seenOptInSensorIDs: [.cameraMotion, .cameraStream]
        )

        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.cameraMotion.rawValue))
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.cameraStream.rawValue))
    }

    func testUpgradeKeepsEveryStaticallyKnownSensorFamily() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        // Sensor IDs that don't come from WebhookSensorId, and so are the ones a registry built
        // only from that enum would silently switch off.
        XCTAssertTrue(container.isEnabled(uniqueID: "pedometer_distance"))
        XCTAssertTrue(container.isEnabled(uniqueID: "battery_level"))
        XCTAssertTrue(container.isEnabled(uniqueID: "battery_state"))
        XCTAssertTrue(container.isEnabled(uniqueID: "camera_in_use"))
        XCTAssertTrue(container.isEnabled(uniqueID: "active_camera"))
        XCTAssertTrue(container.isEnabled(uniqueID: HealthKitSensor.Metric.restingHeartRate.uniqueID))
    }

    func testUpgradeRunsOnlyOnce() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue))

        container.setEnabled(false, forUniqueID: WebhookSensorId.storage.rawValue)

        // A second store over the same defaults must not treat this as a fresh migration and undo
        // the choice above.
        XCTAssertFalse(SensorContainer().isEnabled(uniqueID: WebhookSensorId.storage.rawValue))
    }

    func testUpgradeIsUnaffectedByDenylistEntriesForSensorsThatNoLongerExist() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [
            "a_sensor_that_was_removed",
            WebhookSensorId.storage.rawValue,
        ])

        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue))
        XCTAssertFalse(container.isEnabled(uniqueID: "a_sensor_that_was_removed"))
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue))
    }

    func testUpgradeDropsTheLegacyKeysOnceComplete() throws {
        SensorEnablementStore.seedLegacyStateForTesting(
            disabledSensorIDs: [WebhookSensorId.storage.rawValue],
            seenOptInSensorIDs: [.cameraMotion]
        )

        try generateSensors(withUniqueIDs: [dynamicSensorID])

        let prefs = Current.settingsStore.prefs
        XCTAssertNil(prefs.object(forKey: "disabledSensors"))
        XCTAssertNil(prefs.object(forKey: "sensor_initially_disabled_cameraMotion"))
        // The user's choice survives the keys it used to be stored in.
        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue))
    }

    // MARK: - Sensors whose unique IDs only exist at runtime

    func testDynamicSensorIDsCarryOverOnTheFirstGeneration() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertTrue(container.isEnabled(uniqueID: dynamicSensorID))
    }

    func testDynamicSensorIDsTheUserHadDisabledStayOff() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [dynamicSensorID])

        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertFalse(container.isEnabled(uniqueID: dynamicSensorID))
    }

    func testTurningADynamicSensorOffBeforeItIsEverProducedSticks() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        container.setEnabled(false, forUniqueID: dynamicSensorID)
        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertFalse(container.isEnabled(uniqueID: dynamicSensorID))
    }

    func testSensorsAppearingAfterTheMigrationStayOffUntilEnabled() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        try generateSensors(withUniqueIDs: [dynamicSensorID])
        let laterSensorID = "connectivity_sim_2"
        try generateSensors(withUniqueIDs: [dynamicSensorID, laterSensorID])

        XCTAssertTrue(container.isEnabled(uniqueID: dynamicSensorID))
        XCTAssertFalse(container.isEnabled(uniqueID: laterSensorID))

        container.setEnabled(true, forUniqueID: laterSensorID)
        XCTAssertTrue(container.isEnabled(uniqueID: laterSensorID))
    }

    func testALimitedGenerationDoesNotFinishTheMigration() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        try generateSensors(withUniqueIDs: ["some_other_sensor"], limitedToProvider: true)
        try generateSensors(withUniqueIDs: [dynamicSensorID])

        // A run that only asked some of the providers can't stand in for the complete set, so the
        // battery below still gets its chance to carry over.
        XCTAssertTrue(container.isEnabled(uniqueID: dynamicSensorID))
    }

    // MARK: - First-time installs

    func testFirstRunDefaultsEnableOnlyTheOutOfTheBoxSensors() {
        container.applyFirstRunSensorDefaults()

        XCTAssertTrue(container.isEnabled(uniqueID: "battery_level"))
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.appVersion.rawValue))
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.locationPermission.rawValue))

        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue))
        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue))
        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.cameraMotion.rawValue))
        XCTAssertFalse(container.isEnabled(uniqueID: HealthKitSensor.Metric.steps.uniqueID))
    }

    func testFirstRunDefaultsPickUpThisDevicesBatterySensors() throws {
        container.applyFirstRunSensorDefaults()

        try generateSensors(withUniqueIDs: [dynamicSensorID, "connectivity_sim_1"])

        XCTAssertTrue(container.isEnabled(uniqueID: dynamicSensorID))
        XCTAssertFalse(container.isEnabled(uniqueID: "connectivity_sim_1"))
    }

    func testFirstRunDefaultsLeaveAnUpgradedInstallAlone() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [WebhookSensorId.storage.rawValue])
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue))

        container.applyFirstRunSensorDefaults()

        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue))
    }

    func testFirstRunDefaultsDoNotComeBackWhenAServerIsSetUpAgain() {
        container.applyFirstRunSensorDefaults()
        container.setEnabled(true, forUniqueID: WebhookSensorId.storage.rawValue)

        container.applyFirstRunSensorDefaults()

        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue))
    }

    // MARK: - Helpers

    private func generateSensors(withUniqueIDs uniqueIDs: [String], limitedToProvider: Bool = false) throws {
        MockEnablementSensorProvider.returnedSensors = uniqueIDs.map {
            WebhookSensor(name: $0, uniqueID: $0)
        }
        container.register(provider: MockEnablementSensorProvider.self)

        let response = container.sensors(
            reason: .trigger("unit-test"),
            limitedTo: limitedToProvider ? [MockEnablementSensorProvider.self] : nil,
            server: server
        )
        _ = try hang(Promise(response))
    }

    private class MockEnablementSensorProvider: SensorProvider {
        static var returnedSensors: [WebhookSensor] = []

        required init(request: SensorProviderRequest) {}

        func sensors() -> Promise<[WebhookSensor]> {
            .value(Self.returnedSensors)
        }
    }
}
