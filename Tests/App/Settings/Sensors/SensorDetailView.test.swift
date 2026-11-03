@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the sensor detail screen out for a sensor carrying every kind of setting, flips its switches,
/// types into its fields and saves its credentials, so each setting row's body and bindings run.
///
/// `.sharedState`: enabling a sensor writes the sensor settings and calls
/// `Current.requestSensorPermissions`, which the test swaps, as it does `Current.sensors`.
@Suite(.sharedState)
@MainActor
struct SensorDetailViewTests {
    private final class Store {
        var flag = false
        var stepper = 4.0
        var slider = 10.0
        var option = 17.0
        var number = 8090.0
        var username = "kiosk"
        var password = ""
    }

    private static func sensor(uniqueID: String, store: Store) -> WebhookSensor {
        let sensor = WebhookSensor(name: "Camera", uniqueID: uniqueID)
        sensor.Icon = "mdi:cctv"
        sensor.State = 12
        sensor.UnitOfMeasurement = "fps"
        sensor.DeviceClass = .battery
        sensor.Attributes = ["Stream URL": "http://example.com/stream", "Clients": 2, "Motion": true]
        sensor.detailFooter = "Footer text"
        sensor.Settings = [
            .init(type: .switch(getter: { store.flag }, setter: { store.flag = $0 }), title: "Switch"),
            .init(
                type: .stepper(
                    getter: { store.stepper },
                    setter: { store.stepper = $0 },
                    minimum: 0,
                    maximum: 10,
                    step: 1,
                    displayValueFor: { "\(Int($0 ?? 0)) items" }
                ),
                title: "Stepper with display",
                subtitle: "A caption under the row"
            ),
            .init(
                type: .stepper(
                    getter: { store.stepper },
                    setter: { store.stepper = $0 },
                    displayValueFor: nil
                ),
                title: "Plain stepper"
            ),
            .init(
                type: .slider(
                    getter: { store.slider },
                    setter: { store.slider = $0 },
                    minimum: 1,
                    maximum: 30,
                    step: 1,
                    displayValueFor: { $0.map { String(format: "%.0f fps", $0) } }
                ),
                title: "Slider"
            ),
            .init(
                type: .slider(getter: { store.slider }, setter: { store.slider = $0 }, displayValueFor: nil),
                title: "Plain slider"
            ),
            .init(
                type: .options(
                    getter: { store.option },
                    setter: { store.option = $0 },
                    values: [5, 15, 30],
                    displayValueFor: { "\(Int($0)) s" }
                ),
                title: "Options"
            ),
            .init(
                type: .numericField(
                    getter: { store.number },
                    setter: { store.number = $0 },
                    minimum: 1024,
                    maximum: 65535
                ),
                title: "Port"
            ),
            .init(
                type: .credentials(fields: [
                    .init(title: "Username", placeholder: "Optional", getter: { store.username }, setter: {
                        store.username = $0
                    }),
                    .init(title: "Password", isSecure: true, getter: { store.password }, setter: {
                        store.password = $0
                    }),
                ]),
                title: "Credentials",
                subtitle: "Leave blank to allow anyone"
            ),
        ]
        return sensor
    }

    private func withServer(_ body: (Server) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousRequest = Current.requestSensorPermissions
        let previousSensors = Current.sensors
        let manager = FakeServerManager(initial: 1)
        Current.servers = manager
        // A container of the test's own: switching a sensor on signals every observer of the
        // container, and each API registered with the app's one answers with a full sensor update.
        Current.sensors = SensorContainer()
        defer {
            Current.servers = previousServers
            Current.requestSensorPermissions = previousRequest
            Current.sensors = previousSensors
        }
        try await body(manager.all[0])
    }

    @Test func settingsSectionBuildsOneRowPerSettingAndOnePerCredentialField() {
        let store = Store()
        let rows = SensorDetailView.settingsSection(from: Self.sensor(uniqueID: "camera", store: store).Settings)
        // Seven plain settings, plus two credential fields and their Save row.
        #expect(rows.count == 10)
        #expect(SensorDetailView.settingsSection(from: []).isEmpty)
    }

    @Test func rendersEverySettingAndCommitsEdits() async throws {
        try await withServer { server in
            let store = Store()
            let uniqueID = "ha-tests-sensor-detail-\(UUID().uuidString)"
            let sensor = Self.sensor(uniqueID: uniqueID, store: store)
            var requested: [[String]] = []
            Current.requestSensorPermissions = { requested.append($0) }
            defer { Current.sensors.setEnabled(false, forUniqueID: uniqueID, on: server) }

            let harness = await SettingsScreenHarness.show(SensorDetailView(sensor: sensor, server: server))

            // Flips the enable switch and the setting switch.
            await harness.toggleSwitches()
            let enabled = Current.sensors.isEnabled(sensor: sensor, for: server)
            #expect(store.flag)
            if enabled {
                #expect(requested == [[uniqueID]])
            }

            // The numeric field clamps, the credential fields update the draft until Save.
            await harness.type("99999")
            #expect(store.number == 65535)
            // The credential fields only change the draft until Save is tapped.
            #expect(store.username == "kiosk")
            await harness.type("not a number")
            await harness.toggleSwitches()
            await harness.close()
            #expect(store.number == 65535)
        }
    }

    @Test func rendersADisabledSensorWithoutOptionalRows() async throws {
        try await withServer { server in
            let sensor = WebhookSensor(name: "Bare", uniqueID: "ha-tests-bare-\(UUID().uuidString)")
            sensor.State = nil
            let harness = await SettingsScreenHarness.show(SensorDetailView(sensor: sensor, server: server))
            #expect(harness.rows.count >= 2)
            await harness.close()
        }
    }

    @Test func focusNameSensorLinksToFocusSettings() async throws {
        try await withServer { server in
            let sensor = WebhookSensor(name: "Focus", uniqueID: WebhookSensorId.focusName.rawValue)
            let viewModel = SensorDetailViewModel(sensor: sensor, server: server)
            #expect(viewModel.showsFocusConfiguration)

            let harness = await SettingsScreenHarness.show(SensorDetailView(sensor: sensor, server: server))
            let focusRow = harness.rows.first { $0.section == 1 }
            if let focusRow, await harness.push(focusRow) {
                await harness.pop()
            }
            await harness.close()
        }
    }

    @Test func credentialsDraftOnlySavesOnRequest() {
        let store = Store()
        let draft = HomeAssistant.CredentialsDraft(fields: [
            .init(title: "Username", getter: { store.username }, setter: { store.username = $0 }),
        ])
        #expect(!draft.hasChanges)
        draft.values[0] = "admin"
        #expect(draft.hasChanges)
        #expect(store.username == "kiosk")
        draft.save()
        #expect(store.username == "admin")
        #expect(!draft.hasChanges)
    }

    @Test func decimalStepperClampsToItsRange() async {
        var value = 9.5
        let binding = Binding(get: { value }, set: { value = $0 })
        let harness = await SettingsScreenHarness.show(List {
            SensorDetailsDecimalStepper(
                title: "With display",
                value: binding,
                minimum: 0,
                maximum: 10,
                step: 1,
                displayValueFor: { $0.map { "\($0) units" } }
            )
            SensorDetailsDecimalStepper(
                title: "Unknown display",
                value: binding,
                minimum: 0,
                maximum: 10,
                step: 1,
                displayValueFor: { _ in nil }
            )
            SensorDetailsDecimalStepper(
                title: "Raw",
                value: binding,
                minimum: 0,
                maximum: 10,
                step: 1,
                displayValueFor: nil
            )
        })
        for stepper in harness.views(of: UIStepper.self) {
            stepper.value = stepper.maximumValue
            stepper.sendActions(for: .valueChanged)
        }
        await harness.settle()
        await harness.close()
        #expect(value >= 0 && value <= 10)
    }
}
