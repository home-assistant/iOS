@testable import HomeAssistant

import HADesignSystem
import Shared
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// The lock screen accessories, drawn at the size the families really get.
///
/// These are the widgets that were coming out unreadable on device: a circle of our own painted
/// inside the system's slot, a colour logo that the lock screen's monochrome rendering flattened
/// into a white square, and a glyph small enough to be a smudge. The circular family is the whole
/// widget here — there is no title, no subtitle and no footer to make up for a bad icon — so it is
/// worth pinning on its own rather than leaving it to the gallery.
struct WidgetLockScreenAccessorySnapshotTests {
    /// One action, the way a scripts or open page widget hands its single item over.
    private static var action: WidgetBasicViewModel {
        .init(
            id: "script.morning",
            title: "Good morning",
            subtitle: nil,
            interactionType: .appIntent(.refresh),
            icon: .weatherSunsetUpIcon
        )
    }

    private static var sensor: WidgetBasicViewModel {
        .init(
            id: "sensor.temperature",
            title: "21.5 °C",
            subtitle: "Living room",
            interactionType: .appIntent(.refresh),
            icon: .thermometerIcon
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func actionCircular() {
        assertAccessory(contents: [Self.action], type: .button, family: .accessoryCircular)
    }

    @available(iOS 18, *)
    @MainActor @Test func sensorCircular() {
        assertAccessory(contents: [Self.sensor], type: .sensor, family: .accessoryCircular)
    }

    /// Nothing configured. The widget's own wording has nowhere to go in a circle, so the accessory
    /// falls back to the brand glyph instead of a line of clipped text.
    @available(iOS 18, *)
    @MainActor @Test func emptyCircular() {
        assertAccessory(contents: [], type: .button, family: .accessoryCircular)
    }

    @available(iOS 18, *)
    @MainActor @Test func actionInline() {
        assertAccessory(contents: [Self.action], type: .button, family: .accessoryInline)
    }

    /// What the widget picker draws while the entry is on its way: the system redacts whatever the
    /// provider's placeholder returned. Since every provider now serves the gallery mock there, the
    /// shape the user sees while choosing is the shape they get.
    @available(iOS 18, *)
    @MainActor @Test func actionCircularRedacted() {
        assertAccessory(
            contents: [Self.action],
            type: .button,
            family: .accessoryCircular,
            redacted: true,
            named: "redacted"
        )
    }

    @available(iOS 18, *)
    @MainActor private func assertAccessory(
        contents: [WidgetBasicViewModel],
        type: WidgetType,
        family: WidgetFamily,
        redacted: Bool = false,
        named: String? = nil,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = WidgetGalleryFamilyMetrics.size(for: family)
        let widget = WidgetBasicContainerWrapperView(
            emptyViewGenerator: { AnyView(WidgetEmptyStateView(message: "Nothing configured yet")) },
            contents: contents,
            type: type,
            widgetKind: .scripts,
            family: family
        )
        assertSnapshot(
            // The lock screen is always light-on-dark, whatever the phone's appearance is.
            of: widget
                .redacted(reason: redacted ? .placeholder : [])
                .frame(width: size.width, height: size.height)
                .background(Color.black),
            layout: .fixed(width: size.width, height: size.height),
            traits: .init(userInterfaceStyle: .dark),
            named: named,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
