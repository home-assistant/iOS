@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

struct SensorRowTests {
    @MainActor
    @Test func testRowView() async throws {
        let view = List {
            SensorRow(
                sensor: WebhookSensor(
                    name: "Sensor 1",
                    uniqueID: "1",
                    icon: .abTestingIcon,
                    state: false,
                    unit: nil
                ),
                isEnabled: true
            )
        }
        assertLightDarkSnapshots(of: view)
    }

    /// The badge belongs to the sensor rather than to its state, so it stays on the row whether the
    /// sensor is switched on or off.
    @MainActor
    @Test func testForegroundOnlyRowView() async throws {
        let view = List {
            SensorRow(sensor: Self.cameraMotionSensor(), isEnabled: true)
            SensorRow(sensor: Self.cameraMotionSensor(), isEnabled: false)
        }
        assertLightDarkSnapshots(of: view)
    }

    /// A long name wraps rather than squeezing the badge, which is what keeps the badge readable on
    /// the narrowest row the list can produce.
    @MainActor
    @Test func testForegroundOnlyRowViewWithLongName() async throws {
        let sensor = Self.cameraMotionSensor()
        sensor.Name = "Camera Motion Detected By The Front Facing Camera"
        let view = List {
            Toggle(isOn: .constant(true)) {
                SensorRow(sensor: sensor, isEnabled: true)
            }
        }
        assertLightDarkSnapshots(of: view)
    }

    /// The kiosk sensors keep reporting a value in the background, it just stops changing — the
    /// same badge, because reading a frozen value from Home Assistant is the same trap.
    @MainActor
    @Test func testKioskForegroundOnlyRowViews() async throws {
        let view = List {
            SensorRow(sensor: Self.kioskSensor(
                name: "Kiosk Brightness",
                id: .kioskBrightness,
                icon: "mdi:brightness-6",
                state: 65
            ), isEnabled: true)
            SensorRow(sensor: Self.kioskSensor(
                name: "Kiosk Volume",
                id: .kioskVolume,
                icon: "mdi:volume-high",
                state: 30
            ), isEnabled: true)
            SensorRow(sensor: Self.kioskSensor(
                name: "Kiosk Screensaver",
                id: .kioskScreensaver,
                icon: "mdi:sleep-off",
                state: false
            ), isEnabled: true)
        }
        assertLightDarkSnapshots(of: view)
    }

    private static func kioskSensor(
        name: String,
        id: WebhookSensorId,
        icon: String,
        state: Any
    ) -> WebhookSensor {
        WebhookSensor(name: name, uniqueID: id.rawValue, icon: icon, state: state)
    }

    private static func cameraMotionSensor() -> WebhookSensor {
        let sensor = WebhookSensor(
            name: "Camera Motion",
            uniqueID: WebhookSensorId.cameraMotion.rawValue,
            icon: "mdi:motion-sensor",
            deviceClass: .motion,
            state: false
        )
        sensor.Type = "binary_sensor"
        return sensor
    }
}
