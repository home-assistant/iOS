import Foundation
import PromiseKit
@testable import Shared
import XCTest

class SensorEnablementTests: XCTestCase {
    private var container: SensorContainer!
    private var servers: FakeServerManager!
    private var server: Server!
    private var secondServer: Server!

    /// A battery whose unique ID comes from the hardware, so it can't be known ahead of time.
    private let dynamicSensorID = "battery-serial-1234_level"

    override func setUp() {
        super.setUp()

        servers = FakeServerManager()
        server = servers.addFake()
        secondServer = servers.addFake()
        Current.servers = servers

        SensorEnablementStore.resetForTesting()
        container = SensorContainer()
        container.register(provider: MockEnablementSensorProvider.self)
    }

    override func tearDown() {
        super.tearDown()

        SensorEnablementStore.resetForTesting()
    }

    // MARK: - Migrating an install that predates the allowlist

    func testUpgradeKeepsSensorsTheUserHadNotDisabled() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [WebhookSensorId.storage.rawValue])

        XCTAssertFalse(isEnabledEverywhere(WebhookSensorId.storage.rawValue))
        XCTAssertTrue(isEnabledEverywhere(WebhookSensorId.activity.rawValue))
        XCTAssertTrue(isEnabledEverywhere(WebhookSensorId.appVersion.rawValue))
    }

    func testUpgradeLeavesOptInSensorsOffWhenTheDeviceNeverProducedThem() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        // Absent from the denylist only because this device never ran them, not because the user
        // asked for them.
        XCTAssertFalse(isEnabledEverywhere(WebhookSensorId.cameraMotion.rawValue))
        XCTAssertFalse(isEnabledEverywhere(WebhookSensorId.cameraStream.rawValue))
    }

    /// A sensor added after the allowlist shipped can't be in a legacy denylist, and reading that
    /// silence as "the user wanted it on" is what used to switch new sensors on for free.
    func testUpgradeLeavesSensorsAddedAfterTheLegacyEraOff() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        XCTAssertFalse(isEnabledEverywhere(WebhookSensorId.focusName.rawValue))
    }

    func testUpgradeKeepsOptInSensorsTheUserHadTurnedOn() {
        SensorEnablementStore.seedLegacyStateForTesting(
            disabledSensorIDs: [],
            seenOptInSensorIDs: [.cameraMotion, .cameraStream]
        )

        XCTAssertTrue(isEnabledEverywhere(WebhookSensorId.cameraMotion.rawValue))
        XCTAssertTrue(isEnabledEverywhere(WebhookSensorId.cameraStream.rawValue))
    }

    func testUpgradeKeepsEveryStaticallyKnownSensorFamily() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        // Sensor IDs that don't come from WebhookSensorId, and so are the ones a registry built
        // only from that enum would silently switch off.
        XCTAssertTrue(isEnabledEverywhere("pedometer_distance"))
        XCTAssertTrue(isEnabledEverywhere("battery_level"))
        XCTAssertTrue(isEnabledEverywhere("battery_state"))
        XCTAssertTrue(isEnabledEverywhere("camera_in_use"))
        XCTAssertTrue(isEnabledEverywhere("active_camera"))
        // Apple Health is opt-in, so upgrading is not enough to start reading it.
        XCTAssertFalse(isEnabledEverywhere(HealthKitMetric.restingHeartRate.uniqueID))
    }

    func testUpgradeRunsOnlyOnce() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue, for: server))

        container.setEnabled(false, forUniqueID: WebhookSensorId.storage.rawValue, on: server)

        // A second store over the same defaults must not treat this as a fresh migration and undo
        // the choice above.
        XCTAssertFalse(SensorContainer().isEnabled(uniqueID: WebhookSensorId.storage.rawValue, for: server))
    }

    func testUpgradeIsUnaffectedByDenylistEntriesForSensorsThatNoLongerExist() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [
            "a_sensor_that_was_removed",
            WebhookSensorId.storage.rawValue,
        ])

        XCTAssertFalse(isEnabledEverywhere(WebhookSensorId.storage.rawValue))
        XCTAssertFalse(isEnabledEverywhere("a_sensor_that_was_removed"))
        XCTAssertTrue(isEnabledEverywhere(WebhookSensorId.activity.rawValue))
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
        // The device-wide allowlist only exists to be handed to the servers, and goes once it has.
        XCTAssertNil(prefs.object(forKey: "enabledSensors"))
        // The user's choice survives the keys it used to be stored in.
        XCTAssertFalse(isEnabledEverywhere(WebhookSensorId.storage.rawValue))
    }

    // MARK: - Migrating an install that predates per-server enablement

    /// The selection every server used to share has to reach every server, or an entity someone
    /// relies on stops reporting because they installed an update.
    func testEveryExistingServerInheritsTheOneSelectionTheyShared() {
        SensorEnablementStore.seedDeviceWideAllowlistForTesting(enabledSensorIDs: [
            WebhookSensorId.activity.rawValue,
            WebhookSensorId.appVersion.rawValue,
        ])

        for server in [server!, secondServer!] {
            XCTAssertEqual(
                container.enabledUniqueIDs(for: server),
                Set([WebhookSensorId.activity.rawValue, WebhookSensorId.appVersion.rawValue]),
                server.identifier.rawValue
            )
        }
    }

    func testSensorsTheUserHadSwitchedOffStayOffOnEveryServer() {
        SensorEnablementStore.seedDeviceWideAllowlistForTesting(enabledSensorIDs: [
            WebhookSensorId.activity.rawValue,
        ])

        XCTAssertFalse(isEnabledEverywhere(WebhookSensorId.storage.rawValue))
    }

    func testTheSplitRunsOnlyOnce() {
        SensorEnablementStore.seedDeviceWideAllowlistForTesting(enabledSensorIDs: [
            WebhookSensorId.activity.rawValue,
        ])
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: server))

        container.setEnabled(false, forUniqueID: WebhookSensorId.activity.rawValue, on: server)

        // A second store over the same defaults must not hand the old selection out again.
        let second = SensorContainer()
        XCTAssertFalse(second.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: server))
        XCTAssertTrue(second.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: secondServer))
    }

    /// The split has nobody to hand the selection to until a server exists, and finishing it there
    /// would throw the selection away.
    func testTheSplitWaitsUntilThereIsAServerToInheritIt() {
        SensorEnablementStore.seedDeviceWideAllowlistForTesting(enabledSensorIDs: [
            WebhookSensorId.activity.rawValue,
        ])
        let emptyServers = FakeServerManager()
        Current.servers = emptyServers

        XCTAssertFalse(SensorContainer().isEnabledForAnyServer(uniqueID: WebhookSensorId.activity.rawValue))

        let restored = emptyServers.addFake()
        XCTAssertTrue(SensorContainer().isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: restored))
    }

    // MARK: - Servers added afterwards

    /// Every sensor is opt-in, and a server the user has just added never had any of them reporting
    /// to it, so it starts with nothing rather than with what the other servers happen to receive.
    func testAServerAddedAfterTheSplitStartsWithNothingEnabled() {
        SensorEnablementStore.seedDeviceWideAllowlistForTesting(enabledSensorIDs: [
            WebhookSensorId.activity.rawValue,
        ])
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: server))

        let addedLater = servers.addFake()

        XCTAssertTrue(container.enabledUniqueIDs(for: addedLater).isEmpty)
    }

    func testADynamicSensorIsNotSeededOntoAServerAddedAfterTheSplit() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])
        // Finishes the split, so the server below is one the user added afterwards.
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: server))
        let addedLater = servers.addFake()

        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertTrue(container.isEnabled(uniqueID: dynamicSensorID, for: server))
        XCTAssertFalse(container.isEnabled(uniqueID: dynamicSensorID, for: addedLater))
    }

    func testRemovingAServerForgetsItsSelection() {
        SensorEnablementStore.seedDeviceWideAllowlistForTesting(enabledSensorIDs: [
            WebhookSensorId.activity.rawValue,
        ])
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: secondServer))

        container.forgetSensorSelection(forServerWithIdentifier: secondServer.identifier)

        XCTAssertTrue(container.enabledUniqueIDs(for: secondServer).isEmpty)
        // The other server is untouched.
        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.activity.rawValue, for: server))
    }

    // MARK: - Choosing per server

    func testSwitchingASensorOnForOneServerLeavesTheOtherAlone() {
        container.resetSensorsForFirstRun()

        container.setEnabled(true, forUniqueID: WebhookSensorId.storage.rawValue, on: server)

        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue, for: server))
        XCTAssertFalse(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue, for: secondServer))
    }

    /// Device-level work — observing the camera, reading Apple Health — happens once however many
    /// servers the values reach, so one server wanting a sensor is enough to do it.
    func testASensorCountsAsEnabledWhileAnyServerStillWantsIt() {
        container.resetSensorsForFirstRun()
        container.setEnabled(true, forUniqueID: WebhookSensorId.cameraMotion.rawValue, on: secondServer)

        XCTAssertTrue(container.isEnabledForAnyServer(uniqueID: WebhookSensorId.cameraMotion.rawValue))

        container.setEnabled(false, forUniqueID: WebhookSensorId.cameraMotion.rawValue, on: secondServer)

        XCTAssertFalse(container.isEnabledForAnyServer(uniqueID: WebhookSensorId.cameraMotion.rawValue))
    }

    /// A removed server's leftover choices must not keep hardware awake for a server that is gone.
    func testASensorOnlyARemovedServerWantedNoLongerCountsAsEnabled() {
        container.resetSensorsForFirstRun()
        container.setEnabled(true, forUniqueID: WebhookSensorId.cameraMotion.rawValue, on: secondServer)

        servers.remove(identifier: secondServer.identifier)

        XCTAssertFalse(container.isEnabledForAnyServer(uniqueID: WebhookSensorId.cameraMotion.rawValue))
    }

    func testEnablingForAllServersCoversEveryOneOfThem() {
        container.resetSensorsForFirstRun()

        container.setEnabledForAllServers(true, forUniqueID: WebhookSensorId.kioskBrightness.rawValue)

        XCTAssertTrue(isEnabledEverywhere(WebhookSensorId.kioskBrightness.rawValue))
    }

    // MARK: - Sensors whose unique IDs only exist at runtime

    func testDynamicSensorIDsCarryOverOnTheFirstGeneration() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertTrue(isEnabledEverywhere(dynamicSensorID))
    }

    func testDynamicSensorIDsTheUserHadDisabledStayOff() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [dynamicSensorID])

        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertFalse(isEnabledEverywhere(dynamicSensorID))
    }

    func testTurningADynamicSensorOffBeforeItIsEverProducedSticks() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        for each in [server!, secondServer!] {
            container.setEnabled(false, forUniqueID: dynamicSensorID, on: each)
        }
        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertFalse(isEnabledEverywhere(dynamicSensorID))
    }

    /// A sensor the app has never produced is reporting to nobody, so switching it off before the
    /// migration reaches it keeps it off everywhere rather than starting it up on the servers that
    /// happened not to be the one the user was looking at.
    func testTurningADynamicSensorOffBeforeItExistsKeepsItOffOnEveryServer() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        container.setEnabled(false, forUniqueID: dynamicSensorID, on: server)
        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertFalse(isEnabledEverywhere(dynamicSensorID), storedEnablementState)
    }

    /// Switching a not-yet-produced sensor on for one server must not hand it to the others when
    /// the dynamic pass runs: the user asked for it in one place.
    func testTurningADynamicSensorOnForOneServerLeavesTheOthersAlone() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [dynamicSensorID])

        container.setEnabled(true, forUniqueID: dynamicSensorID, on: server)
        try generateSensors(withUniqueIDs: [dynamicSensorID])

        XCTAssertTrue(container.isEnabled(uniqueID: dynamicSensorID, for: server), storedEnablementState)
        XCTAssertFalse(container.isEnabled(uniqueID: dynamicSensorID, for: secondServer), storedEnablementState)
    }

    /// Removing the only server that wanted a sensor changes what device-level work should be
    /// doing, which it only finds out about by being told.
    func testForgettingAServerSignalsTheSensorsItWasTheLastToWant() {
        container.resetSensorsForFirstRun()
        container.setEnabled(true, forUniqueID: WebhookSensorId.cameraMotion.rawValue, on: secondServer)

        let observer = MockSensorObserver()
        container.register(observer: observer)
        servers.remove(identifier: secondServer.identifier)
        container.forgetSensorSelection(forServerWithIdentifier: secondServer.identifier)

        XCTAssertEqual(observer.signalledUniqueIDs, [WebhookSensorId.cameraMotion.rawValue])
        XCTAssertFalse(container.isEnabledForAnyServer(uniqueID: WebhookSensorId.cameraMotion.rawValue))
    }

    func testSensorsAppearingAfterTheMigrationStayOffUntilEnabled() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        try generateSensors(withUniqueIDs: [dynamicSensorID])
        let laterSensorID = "connectivity_sim_2"
        try generateSensors(withUniqueIDs: [dynamicSensorID, laterSensorID])

        XCTAssertTrue(container.isEnabled(uniqueID: dynamicSensorID, for: server), storedEnablementState)
        XCTAssertFalse(container.isEnabled(uniqueID: laterSensorID, for: server), storedEnablementState)

        container.setEnabled(true, forUniqueID: laterSensorID, on: server)
        XCTAssertTrue(container.isEnabled(uniqueID: laterSensorID, for: server))
    }

    func testALimitedGenerationDoesNotFinishTheMigration() throws {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [])

        try generateSensors(withUniqueIDs: ["some_other_sensor"], limitedToProvider: true)

        // A limited run only asks some of the providers, so it can't stand in for the complete set
        // and must decide nothing: were it to seed, this sensor would come back enabled.
        // Carrying dynamic IDs over on the next full run is covered by the first-generation test,
        // which doesn't need a second `hang()` to get there — every one of those spins the run
        // loop, letting another suite's in-flight generation finish this migration first.
        XCTAssertFalse(container.isEnabled(uniqueID: "some_other_sensor", for: server), storedEnablementState)
    }

    /// The persisted enablement state, for failure messages: the migration is driven entirely by
    /// these keys, so they say which step went wrong.
    private var storedEnablementState: String {
        let prefs = Current.settingsStore.prefs
        let enabled = prefs.object(forKey: "enabledSensors") as? [String] ?? []
        let byServer = prefs.object(forKey: "enabledSensorsByServer") as? [String: [String]] ?? [:]
        let disabled = prefs.object(forKey: "disabledSensors") as? [String] ?? []
        let state = prefs.string(forKey: "sensorEnablementMigrationState") ?? "nil"
        let inheriting = prefs.object(forKey: "sensorEnablementInheritingServers") as? [String]
        let perServer = byServer.map { "\($0.key)(\($0.value.count))=\($0.value.suffix(6))" }.sorted()
        return "migration=\(state) inheriting=\(inheriting?.count.description ?? "nil") " +
            "disabled=\(disabled) enabled(\(enabled.count))=\(enabled.suffix(6)) byServer=\(perServer)"
    }

    // MARK: - First-time installs

    /// Every sensor is opt-in, so a new install reports nothing until the user picks something.
    func testFirstRunEnablesNothing() {
        container.resetSensorsForFirstRun()

        for uniqueID in [
            "battery_level",
            WebhookSensorId.appVersion.rawValue,
            WebhookSensorId.locationPermission.rawValue,
            WebhookSensorId.storage.rawValue,
            WebhookSensorId.activity.rawValue,
            WebhookSensorId.cameraMotion.rawValue,
            HealthKitMetric.restingHeartRate.uniqueID,
        ] {
            XCTAssertFalse(isEnabledEverywhere(uniqueID), uniqueID)
        }
    }

    func testFirstRunLeavesTheSensorsThisDeviceProducesLaterOff() throws {
        container.resetSensorsForFirstRun()

        try generateSensors(withUniqueIDs: [dynamicSensorID, "connectivity_sim_1"])

        XCTAssertFalse(isEnabledEverywhere(dynamicSensorID))
        XCTAssertFalse(isEnabledEverywhere("connectivity_sim_1"))
    }

    func testFirstRunLeavesAnUpgradedInstallAlone() {
        SensorEnablementStore.seedLegacyStateForTesting(disabledSensorIDs: [WebhookSensorId.storage.rawValue])
        XCTAssertTrue(isEnabledEverywhere(WebhookSensorId.activity.rawValue))

        container.resetSensorsForFirstRun()

        XCTAssertTrue(isEnabledEverywhere(WebhookSensorId.activity.rawValue))
    }

    func testFirstRunDoesNotComeBackWhenAServerIsSetUpAgain() {
        container.resetSensorsForFirstRun()
        container.setEnabled(true, forUniqueID: WebhookSensorId.storage.rawValue, on: server)

        container.resetSensorsForFirstRun()

        XCTAssertTrue(container.isEnabled(uniqueID: WebhookSensorId.storage.rawValue, for: server))
    }

    // MARK: - Helpers

    /// Asserting per server would say the same thing twice in every migration test, where what is
    /// being checked is that both of them ended up with the selection.
    private func isEnabledEverywhere(_ uniqueID: String) -> Bool {
        let enabled = [server!, secondServer!].map { container.isEnabled(uniqueID: uniqueID, for: $0) }
        XCTAssertEqual(enabled.first, enabled.last, "\(uniqueID) differs between servers")
        return enabled.allSatisfy { $0 }
    }

    private func generateSensors(withUniqueIDs uniqueIDs: [String], limitedToProvider: Bool = false) throws {
        MockEnablementSensorProvider.returnedSensors = uniqueIDs.map {
            WebhookSensor(name: $0, uniqueID: $0)
        }

        let response = container.sensors(
            reason: .trigger("unit-test"),
            limitedTo: limitedToProvider ? [MockEnablementSensorProvider.self] : nil,
            server: server
        )
        _ = try hang(Promise(response))
    }

    /// Records what the container told its observers, which is how "the signal went out" is
    /// observed without an API to receive it.
    private class MockSensorObserver: SensorObserver {
        var signalledUniqueIDs: [String] = []

        func sensorContainer(_ container: SensorContainer, didUpdate update: SensorObserverUpdate) {}

        func sensorContainer(
            _ container: SensorContainer,
            didSignalForUpdateBecause reason: SensorContainerUpdateReason,
            lastUpdate: SensorObserverUpdate?
        ) {
            guard case let .settingsChange(changedUniqueIDs, _) = reason else { return }
            signalledUniqueIDs.append(contentsOf: changedUniqueIDs)
        }
    }

    private class MockEnablementSensorProvider: SensorProvider {
        static var returnedSensors: [WebhookSensor] = []

        required init(request: SensorProviderRequest) {}

        func sensors() -> Promise<[WebhookSensor]> {
            .value(Self.returnedSensors)
        }
    }
}
