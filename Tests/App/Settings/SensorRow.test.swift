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
                    unit: nil,
                    entityCategory: nil
                ),
                isEnabled: true
            )
        }
        assertLightDarkSnapshots(of: view)
    }
}
