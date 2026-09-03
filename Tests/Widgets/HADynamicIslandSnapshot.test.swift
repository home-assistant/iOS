@testable import HomeAssistant

import Shared
import SharedTesting

import SnapshotTesting
import SwiftUI
import Testing

struct HADynamicIslandSnapshotTests {
    /// The compact trailing slot is 50 pt wide, so a timer past an hour has to scale down to keep
    /// all of `H:MM:SS` on screen. These references pin that, along with the critical text and the
    /// progress percentage rendered in the same slot.
    ///
    /// A fixed layout is used rather than `.sizeThatFits`: the latter proposes a compressed size,
    /// which collapses `frame(maxWidth:)` to zero and renders an empty image.
    ///
    /// Only one appearance is recorded — the Dynamic Island always draws on black, so the light and
    /// dark renders would be identical.
    @available(iOS 26.0, *)
    @MainActor @Test func compactTrailingSnapshots() {
        for sample in Self.makeSamples() {
            assertSnapshot(
                of: HACompactTrailingView(state: sample.state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black),
                layout: .fixed(width: 70, height: 30),
                named: sample.name
            )
        }
    }

    /// The expanded presentation is one view in one full-width region, so these references are the
    /// layout itself rather than a re-composition of it. `.sizeThatFits` is what makes them useful:
    /// the image height is the height the island asks for, so a state with no progress bar records
    /// a visibly shorter image than one with a bar.
    ///
    /// The width is the island's content width on an iPhone 17 Pro, and the ideal height is taken
    /// explicitly because `.sizeThatFits` proposes a compressed size in both axes — a `Text`
    /// measured that way is squeezed onto one truncated line instead of wrapping.
    @available(iOS 26.0, *)
    @MainActor @Test func expandedSnapshots() {
        MaterialDesignIcons.register()
        for sample in Self.makeExpandedSamples() {
            assertSnapshot(
                of: HAExpandedContentView(attributes: Self.attributes, state: sample.state)
                    .frame(width: Self.expandedContentWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(.black)
                    .environment(\.locale, Locale(identifier: "en_US")),
                layout: .sizeThatFits,
                named: sample.name
            )
        }
    }

    private static let expandedContentWidth: CGFloat = 336

    @available(iOS 17.2, *)
    private static var attributes: HALiveActivityAttributes {
        HALiveActivityAttributes(tag: "preview", title: "Laundry")
    }

    /// Both chronometer samples use a fully-past bounded interval (`chronometerStart` <
    /// `countdownEnd`, both before now): the ticking text renders against the wall clock, so a
    /// future timer would drift every run, while a past bounded one freezes at its total duration.
    @available(iOS 17.2, *)
    private static func makeSamples() -> [(name: String, state: HALiveActivityAttributes.ContentState)] {
        let timerStart = Date(timeIntervalSince1970: 1_700_000_000)
        return [
            (
                // 2 h 20 min 13 s — the case that used to be clipped in the slot.
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
                // 25 min — two fields, so it stays at full size.
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

    /// The chronometer samples reuse the past bounded interval `makeSamples()` explains.
    @available(iOS 17.2, *)
    private static func makeExpandedSamples() -> [(name: String, state: HALiveActivityAttributes.ContentState)] {
        let timerStart = Date(timeIntervalSince1970: 1_700_000_000)
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
                    countdownEnd: timerStart.addingTimeInterval(1500),
                    chronometerStart: timerStart,
                    icon: "timer",
                    color: "#FF9800"
                )
            ),
            (
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
                "criticalText",
                .init(
                    message: "Charging paused",
                    criticalText: "20%",
                    icon: "battery-alert",
                    color: "#F44336"
                )
            ),
            (
                "messageOnly",
                .init(
                    message: "Front door unlocked",
                    icon: "door-open",
                    color: "#4CAF50"
                )
            ),
            (
                "longMessage",
                .init(
                    message: "Dishwasher finished its eco cycle and is cooling down before the door unlocks",
                    progress: 92,
                    progressMax: 100,
                    icon: "dishwasher",
                    color: "#03A9F4"
                )
            ),
            (
                "withoutIcon",
                .init(
                    message: "Washing cycle",
                    progress: 40,
                    progressMax: 100
                )
            ),
        ]
    }
}
