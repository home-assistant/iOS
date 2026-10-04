@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the sensor detail screen out for sensors carrying every kind of setting, so SwiftUI evaluates
/// the header, state, attribute and settings sections along with each setting row type.
@MainActor
@Suite(.serialized)
struct SensorDetailViewRenderTests {
    @Test func settingsSectionBuildsOneRowPerSettingAndOnePerCredentialField() {
        let rows = SensorDetailView.settingsSection(from: Self.settings(recorder: SettingsRecorder()))
        // switch, stepper (with display), stepper (plain), slider, options, numeric field,
        // two credential fields plus their save row.
        #expect(rows.count == 9)
    }

    @Test func settingsSectionIsEmptyWithoutSettings() {
        #expect(SensorDetailView.settingsSection(from: []).isEmpty)
    }

    @Test func rendersAnEnabledSensorWithEverySettingKind() throws {
        try withSensors { server in
            let recorder = SettingsRecorder()
            let sensor = WebhookSensor(
                name: "Camera Motion",
                uniqueID: WebhookSensorId.cameraMotion.rawValue,
                icon: "mdi:motion-sensor",
                deviceClass: .battery,
                state: true
            )
            sensor.Attributes = ["frames": 12, "area": "Hallway"]
            sensor.Settings = Self.settings(recorder: recorder)
            sensor.detailFooter = "Footer"
            Current.sensors.setEnabled(true, forUniqueID: WebhookSensorId.cameraMotion.rawValue, on: server)

            let viewModel = SensorDetailViewModel(sensor: sensor, server: server)
            #expect(viewModel.isEnabled)
            #expect(viewModel.deviceClass == "battery")
            #expect(viewModel.attributes.map(\.key) == ["area", "frames"])
            #expect(viewModel.settingsViews.count == 9)
            #expect(viewModel.showsFocusConfiguration == false)

            render(SensorDetailView(sensor: sensor, server: server))
        }
    }

    @Test func rendersADisabledFocusNameSensorWithItsFocusLink() throws {
        try withSensors { server in
            let sensor = WebhookSensor(name: "Focus Name", uniqueID: WebhookSensorId.focusName.rawValue)
            let viewModel = SensorDetailViewModel(sensor: sensor, server: server)
            #expect(viewModel.showsFocusConfiguration)
            #expect(viewModel.isEnabled == false)
            #expect(viewModel.settingsViews.isEmpty)

            render(SensorDetailView(sensor: sensor, server: server))
        }
    }

    @Test func decimalStepperRendersWithAndWithoutADisplayFormatter() {
        let binding = Binding.constant(2.5)
        render(SensorDetailsDecimalStepper(
            title: "Interval",
            value: binding,
            minimum: 0,
            maximum: 10,
            step: 0.5,
            displayValueFor: { $0.map { "\($0) s" } }
        ))
        render(SensorDetailsDecimalStepper(
            title: "Interval",
            value: binding,
            minimum: 0,
            maximum: 10,
            step: 0.5,
            displayValueFor: nil
        ))
        #expect(binding.wrappedValue == 2.5)
    }

    private final class SettingsRecorder {
        var flag = true
        var number = 5.0
        var username = "kiosk"
        var password = ""
    }

    private static func settings(recorder: SettingsRecorder) -> [WebhookSensorSetting] {
        [
            WebhookSensorSetting(
                type: .switch(getter: { recorder.flag }, setter: { recorder.flag = $0 }),
                title: "Flag",
                subtitle: "Explains the flag"
            ),
            WebhookSensorSetting(
                type: .stepper(
                    getter: { recorder.number },
                    setter: { recorder.number = $0 },
                    minimum: 0,
                    maximum: 10,
                    step: 1,
                    displayValueFor: { $0.map { "\($0) units" } }
                ),
                title: "Stepper"
            ),
            WebhookSensorSetting(
                type: .stepper(
                    getter: { recorder.number },
                    setter: { recorder.number = $0 },
                    displayValueFor: nil
                ),
                title: "Plain stepper"
            ),
            WebhookSensorSetting(
                type: .slider(
                    getter: { recorder.number },
                    setter: { recorder.number = $0 },
                    minimum: 1,
                    maximum: 30,
                    step: 1,
                    displayValueFor: nil
                ),
                title: "Slider"
            ),
            WebhookSensorSetting(
                type: .options(
                    getter: { recorder.number },
                    setter: { recorder.number = $0 },
                    values: [2, 5, 15],
                    displayValueFor: { "\(Int($0)) s" }
                ),
                title: "Options"
            ),
            WebhookSensorSetting(
                type: .numericField(
                    getter: { recorder.number },
                    setter: { recorder.number = $0 },
                    minimum: 1,
                    maximum: 100
                ),
                title: "Port"
            ),
            WebhookSensorSetting(
                type: .credentials(fields: [
                    .init(title: "Username", getter: { recorder.username }, setter: { recorder.username = $0 }),
                    .init(
                        title: "Password",
                        placeholder: "Required",
                        isSecure: true,
                        getter: { recorder.password },
                        setter: { recorder.password = $0 }
                    ),
                ]),
                title: "Credentials",
                subtitle: "Stream credentials"
            ),
        ]
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: NavigationView { view })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1600))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func withSensors(_ body: (Server) throws -> Void) throws {
        let previousSensors = Current.sensors
        let previousServers = Current.servers
        defer {
            SensorEnablementStore.resetForTesting()
            Current.sensors = previousSensors
            Current.servers = previousServers
        }

        let servers = FakeServerManager()
        let server = servers.addFake()
        Current.servers = servers
        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
        Current.sensors.resetSensorsForFirstRun()

        try body(server)
    }
}
