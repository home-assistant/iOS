@testable import HomeAssistant

import Shared
import SharedTesting

import SnapshotTesting
import SwiftUI
import Testing

struct HALiveActivitySnapshotTests {
    @available(iOS 26.0, *)
    @MainActor @Test func regularSizeSnapshots() {
        MaterialDesignIcons.register()
        let attributes = Self.attributes
        for sample in Self.makeSamples() {
            assertLightDarkSnapshots(
                of: HALockScreenView(attributes: attributes, state: sample.state),
                layout: .fixed(width: 360, height: 130),
                named: sample.name
            )
        }
    }

    @available(iOS 26.0, *)
    @MainActor @Test func smallSizeSnapshots() {
        MaterialDesignIcons.register()
        let attributes = Self.attributes
        for sample in Self.makeSamples() {
            assertLightDarkSnapshots(
                of: HALiveActivityCompactView(attributes: attributes, state: sample.state),
                layout: .fixed(width: 182, height: 84),
                named: sample.name
            )
        }
    }

    /// Shared static attributes for every sample — mirrors the app's Live Activity previews.
    @available(iOS 17.2, *)
    private static var attributes: HALiveActivityAttributes {
        HALiveActivityAttributes(tag: "preview", title: "Laundry")
    }

    /// The Live Activity content-state samples the app ships in its previews. Kept in one place so
    /// the regular (`.medium`, Lock Screen) and small (`.small`, Smart Stack / CarPlay) renders
    /// exercise the exact same inputs.
    ///
    /// The chronometer sample uses a fully-past bounded interval (`chronometerStart` < `countdownEnd`,
    /// both before now) on purpose: `Text(timerInterval:)` / `ProgressView(timerInterval:)` render
    /// against the wall clock, so a future countdown would drift every run. A past bounded interval
    /// freezes at its final value (full duration, full bar), keeping the snapshot deterministic while
    /// still exercising the chronometer layout.
    @available(iOS 17.2, *)
    private static func makeSamples() -> [(name: String, state: HALiveActivityAttributes.ContentState)] {
        let timerStart = Date(timeIntervalSince1970: 1_700_000_000)
        let timerEnd = timerStart.addingTimeInterval(1500)
        return [
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
            (
                "chronometer",
                .init(
                    message: "Pasta",
                    chronometer: true,
                    countdownEnd: timerEnd,
                    chronometerStart: timerStart,
                    icon: "timer",
                    color: "#FF9800"
                )
            ),
            (
                "criticalText",
                .init(
                    message: "Charging paused",
                    criticalText: "20%",
                    icon: "battery-alert",
                    color: "#F44336"
                )
            ),
        ]
    }
}
