@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

struct HealthSensorRowTests {
    @MainActor
    @Test func testRowViews() async throws {
        let view = List {
            HealthSensorRow(metric: .restingHeartRate, stateDescription: "62 bpm", isEnabled: .constant(true))
            HealthSensorRow(metric: .restingHeartRate, stateDescription: nil, isEnabled: .constant(false))
        }
        assertLightDarkSnapshots(of: view)
    }

    /// The badge is a fact about the sensor rather than its state, so it stays on the row whether the
    /// sensor is switched on or off, and sits under the value rather than beside it.
    @MainActor
    @Test func testRequiresAppleWatchRowViews() async throws {
        let standHours = try #require(HealthKitMetric.metric(uniqueID: "health_apple_stand_hours"))
        let exerciseGoal = try #require(HealthKitMetric.metric(uniqueID: "health_apple_exercise_time_goal"))
        let view = List {
            HealthSensorRow(metric: standHours, stateDescription: "10 hours", isEnabled: .constant(true))
            HealthSensorRow(metric: exerciseGoal, stateDescription: nil, isEnabled: .constant(false))
        }
        assertLightDarkSnapshots(of: view)
    }

    /// A footer explains one sensor at length, under the whole row rather than inside it.
    @MainActor
    @Test func testFooterRowViews() async throws {
        let moveGoal = try #require(HealthKitMetric.metric(uniqueID: "health_active_energy_burned_goal"))
        let inBed = try #require(HealthKitMetric.metric(uniqueID: "health_sleep_in_bed"))
        let view = List {
            HealthSensorRow(metric: moveGoal, stateDescription: "610 kcal", isEnabled: .constant(true))
            HealthSensorRow(metric: inBed, stateDescription: "unavailable", isEnabled: .constant(true))
        }
        assertLightDarkSnapshots(of: view)
    }

    /// Both facts the badge can state, side by side, so a change to the shared capsule shows up once.
    @MainActor
    @Test func testNoteBadges() async throws {
        let view = List {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                SensorNoteBadge.foregroundOnly
                SensorNoteBadge.requiresAppleWatch
            }
        }
        assertLightDarkSnapshots(of: view)
    }
}
