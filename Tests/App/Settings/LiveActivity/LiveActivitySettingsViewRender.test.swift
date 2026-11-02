#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Drives the Live Activity settings screen through its rows, sample catalog and YAML viewer.
/// Shared state: it swaps `Current.liveActivityRegistry` and can start a real local Live Activity.
@Suite(.sharedState)
@MainActor
struct LiveActivitySettingsViewRenderTests {
    @available(iOS 17.2, *)
    @Test func syncAsksTheRegistryToReattach() async throws {
        let registry = RecordingLiveActivityRegistry()
        let previous = Current.liveActivityRegistry
        Current.liveActivityRegistry = registry
        defer { Current.liveActivityRegistry = previous }

        let driver = await SwiftUIScreenDriver.show(LiveActivitySettingsView())
        defer { driver.close() }
        #expect(driver.sectionCount == Row.sectionCount)

        await driver.tapRow(Row.sync)
        await #expect(driver.waitUntil { registry.reattachCount == 1 })
        // The "synced" confirmation row appears once the reload finishes.
        await #expect(driver.waitUntil { driver.rowCount(inSection: Row.sync.section) == 2 })
    }

    /// Opens every sample, then its YAML, so each sample's payload is built and highlighted.
    @available(iOS 17.2, *)
    @Test func everySampleOpensItsDetailAndYAML() async throws {
        let driver = await SwiftUIScreenDriver.show(LiveActivitySettingsView())
        defer { driver.close() }

        try await #require(driver.push(Row.samples))
        let sampleRows = driver.rows
        #expect(sampleRows.count > 10)

        for sample in sampleRows {
            try await #require(driver.push(sample), "sample \(sample) did not open")
            try await #require(driver.push(Row.showYAML), "YAML for \(sample) did not open")
            await driver.pop()
            await driver.pop()
        }
        #expect(driver.depth == 2)
    }

    /// The YAML viewer's toolbar copies the sample's YAML and then says it did.
    @available(iOS 17.2, *)
    @Test func theYAMLViewerCopiesItsYAML() async throws {
        let driver = await SwiftUIScreenDriver.show(LiveActivitySettingsView())
        defer { driver.close() }

        try await #require(driver.push(Row.samples))
        try await #require(driver.push(IndexPath(item: 0, section: 0)))
        try await #require(driver.push(Row.showYAML))

        let pasteboard = UIPasteboard.general
        let previous = pasteboard.string
        defer { pasteboard.string = previous ?? "" }
        let copied = await driver.tapBarButton(titled: L10n.LiveActivity.Samples.copy)
        #expect(copied)
        #expect(pasteboard.hasStrings)
        await #expect(driver.waitUntil {
            driver.barButtons.contains {
                $0.title == L10n.LiveActivity.Samples.copied || $0.accessibilityLabel == L10n.LiveActivity.Samples
                    .copied
            }
        })
    }

    /// Starting the plain sample requests a real local activity, which the root list then shows.
    @available(iOS 17.2, *)
    @Test func startingASampleListsTheActivity() async throws {
        let registry = RecordingLiveActivityRegistry()
        let previous = Current.liveActivityRegistry
        Current.liveActivityRegistry = registry
        defer { Current.liveActivityRegistry = previous }
        await Self.endAllActivities()

        let driver = await SwiftUIScreenDriver.show(LiveActivitySettingsView())
        defer { driver.close() }

        try await #require(driver.push(Row.samples))
        // The first static sample is the plain one, tagged `debug-plain`.
        try await #require(driver.push(IndexPath(item: 0, section: 0)))
        await driver.tapRow(Row.start)
        await #expect(driver.waitUntil { driver.rowCount(inSection: Row.start.section) == 2 })

        let started = await driver.waitUntil { !Activity<HALiveActivityAttributes>.activities.isEmpty }
        await driver.popToRoot()
        guard started else { return } // Live Activities can be disabled on the simulator.

        // The active section lists the activity followed by "End all".
        await #expect(driver.waitUntil { driver.rowCount(inSection: Row.active) >= 2 })
        await driver.tapRow(IndexPath(item: driver.rowCount(inSection: Row.active) - 1, section: Row.active))
        await #expect(driver.waitUntil { driver.alert != nil })
        await driver.tapAlertButton(L10n.LiveActivity.EndAll.Confirm.button)
        await #expect(driver.waitUntil { registry.endedTags.contains("debug-plain") })
        await Self.endAllActivities()
    }

    /// Rows of the screen, by position: the header, status, active, sync, samples and docs sections.
    private enum Row {
        static let sectionCount = 6
        static let active = 2
        static let sync = IndexPath(item: 0, section: 3)
        static let samples = IndexPath(item: 0, section: 4)
        /// On a sample's detail screen.
        static let start = IndexPath(item: 0, section: 0)
        static let showYAML = IndexPath(item: 0, section: 1)
    }

    @available(iOS 17.2, *)
    private static func endAllActivities() async {
        for activity in Activity<HALiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

private final class RecordingLiveActivityRegistry: LiveActivityRegistryProtocol {
    private(set) var reattachCount = 0
    private(set) var endedTags: [String] = []

    @available(iOS 17.2, *)
    func startOrUpdate(
        tag: String,
        title: String,
        serverWebhookId: String?,
        state: HALiveActivityAttributes.ContentState,
        relevanceScore: Double?,
        alert: Bool
    ) async throws -> Bool {
        true
    }

    @available(iOS 17.2, *)
    func end(tag: String, dismissalPolicy: ActivityUIDismissalPolicy) async {
        await MainActor.run { endedTags.append(tag) }
    }

    @available(iOS 17.2, *)
    func reattach() async {
        await MainActor.run { reattachCount += 1 }
    }

    @available(iOS 17.2, *)
    func startObservingPushToStartToken() async {}
}
#endif
