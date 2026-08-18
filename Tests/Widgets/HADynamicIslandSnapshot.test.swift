@testable import HomeAssistant

import Shared
import SharedTesting

import SnapshotTesting
import SwiftUI
import Testing

struct HADynamicIslandSnapshotTests {
    /// The compact trailing slot is ~44 pt wide, so the chronometer has to fit in two fields
    /// (`H:MM` from an hour up, `M:SS` below it). These references pin that: an over-an-hour timer
    /// must read `2:20`, not a clipped `2:20:13`.
    ///
    /// Only one appearance is recorded — the Dynamic Island always draws on black, so the light and
    /// dark renders would be identical.
    @available(iOS 26.0, *)
    @MainActor @Test func compactTrailingSnapshots() {
        for sample in Self.makeSamples() {
            assertSnapshot(
                of: HACompactTrailingView(state: sample.state)
                    .padding(DesignSystem.Spaces.one)
                    .background(.black),
                layout: .sizeThatFits,
                named: sample.name
            )
        }
    }

    /// Both chronometer samples use a fully-past bounded interval (`chronometerStart` <
    /// `countdownEnd`, both before now): the ticking text renders against the wall clock, so a
    /// future timer would drift every run, while a past bounded one freezes at its total duration.
    @available(iOS 17.2, *)
    private static func makeSamples() -> [(name: String, state: HALiveActivityAttributes.ContentState)] {
        let timerStart = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            (
                // 2 h 20 min 13 s — the case that used to overflow the slot as "2:20:13".
                "chronometerOverAnHour",
                .init(
                    message: "Pasta",
                    chronometer: true,
                    countdownEnd: timerStart.addingTimeInterval(8413),
                    chronometerStart: timerStart,
                    icon: "timer",
                    color: "#FF9800"
                )
            ),
            (
                // 25 min — below an hour, so minutes and seconds stay visible.
                "chronometerUnderAnHour",
                .init(
                    message: "Pasta",
                    chronometer: true,
                    countdownEnd: timerStart.addingTimeInterval(1500),
                    chronometerStart: timerStart,
                    icon: "timer",
                    color: "#FF9800"
                )
            ),
            (
                // `critical_text` is shown as sent, scaled down rather than ellipsized.
                "criticalText",
                .init(
                    message: "Charging paused",
                    criticalText: "03:20:13",
                    icon: "battery-alert",
                    color: "#F44336"
                )
            ),
            (
                "progress",
                .init(
                    message: "Washing cycle",
                    progress: 40,
                    progressMax: 100,
                    icon: "washing-machine",
                    color: "#03A9F4"
                )
            ),
        ]
    }
}
