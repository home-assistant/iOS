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

    /// `.sizeThatFits` at a fixed width is the point of these references: the image height is the
    /// height the expanded regions ask for, so a state that leaves a region empty records a shorter
    /// island than one that fills every region, and padding around an empty region shows up as a
    /// taller image.
    @available(iOS 26.0, *)
    @MainActor @Test func expandedSnapshots() {
        MaterialDesignIcons.register()
        for sample in Self.makeExpandedSamples() {
            assertSnapshot(
                of: ExpandedRegions(attributes: Self.attributes, state: sample.state)
                    .environment(\.locale, Locale(identifier: "en_US")),
                layout: .sizeThatFits,
                named: sample.name
            )
        }
    }

    /// Stand-in for the way the system composes the four expanded regions: leading, center and
    /// trailing on one row, bottom underneath. The system owns the real geometry and content
    /// margins, so this pins each region's content and height, not the island's exact pixels.
    ///
    /// The center column is given a definite width and its ideal height because `.sizeThatFits`
    /// proposes a compressed size in both axes: a `Text` measured that way is squeezed onto one
    /// truncated line, where the real region has the width and height to wrap into.
    @available(iOS 17.2, *)
    private struct ExpandedRegions: View {
        let attributes: HALiveActivityAttributes
        let state: HALiveActivityAttributes.ContentState

        private static let width: CGFloat = 340
        private static let centerWidth: CGFloat = 200

        var body: some View {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                HStack(spacing: DesignSystem.Spaces.one) {
                    HADynamicIslandIconContainerView(slug: state.icon, color: state.color)

                    HAExpandedCenterView(attributes: attributes, state: state)
                        .frame(width: Self.centerWidth, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    HAExpandedTrailingView(state: state)
                }

                HAExpandedBottomView(state: state)
            }
            .padding(DesignSystem.Spaces.oneAndHalf)
            .frame(width: Self.width)
            .background(.black)
        }
    }

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
