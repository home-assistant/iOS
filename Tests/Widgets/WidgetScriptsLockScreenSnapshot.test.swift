@testable import HomeAssistant

import HADesignSystem
import Shared
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// The Run Scripts widget on the lock screen, drawn the way the widget draws it: the script's
/// glyph, wrapped in the intent button that runs it, on the system's accessory background.
///
/// What these pin is the arrangement, not just the look. The button's label has to be the whole
/// slot — a tap on the lock screen only runs the intent when it lands on the label, and lands on the
/// app otherwise (home-assistant/iOS#5642). `controlOutlined` draws that label's bounds so the
/// snapshot shows the control covering the slot, and `deepLink` is the same accessory when it is a
/// link rather than a button, which is what the Open Page widget draws.
struct WidgetScriptsLockScreenSnapshotTests {
    /// One script, the way the scripts widget hands its single accessory item over.
    private static var script: WidgetBasicViewModel {
        .init(
            id: "script.morning",
            title: "Good morning",
            subtitle: nil,
            interactionType: .appIntent(.script(
                id: "script.morning",
                entityId: "script.morning",
                serverId: "1",
                name: "Good morning",
                showConfirmationNotification: true
            )),
            icon: .weatherSunsetUpIcon
        )
    }

    /// The same glyph reached through a deep link instead of an intent.
    private static var page: WidgetBasicViewModel {
        .init(
            id: "lovelace",
            title: "Overview",
            subtitle: nil,
            interactionType: .widgetURL(URL(string: "homeassistant://navigate/lovelace/0")!),
            icon: .viewDashboardIcon
        )
    }

    private static var size: CGSize {
        WidgetGalleryFamilyMetrics.size(for: .accessoryCircular)
    }

    /// The scripts widget's accessory: an intent button around the glyph.
    @available(iOS 18, *)
    @MainActor @Test func runsScript() {
        assertAccessory(of: widget(Self.script))
    }

    /// What the widget picker shows while the entry is on its way.
    @available(iOS 18, *)
    @MainActor @Test func runsScriptRedacted() {
        assertAccessory(of: widget(Self.script).redacted(reason: .placeholder), named: "redacted")
    }

    /// The Open Page widget's accessory: a link around the glyph.
    @available(iOS 18, *)
    @MainActor @Test func deepLink() {
        assertAccessory(of: widget(Self.page))
    }

    /// The control's bounds, drawn. The outline is what the button is handed as its label, and it
    /// has to reach the edge of the slot on every side: a tap anywhere in the circle is then a tap
    /// on the button, and never a plain tap that launches the app.
    @available(iOS 18, *)
    @MainActor @Test func controlOutlined() {
        assertAccessory(
            of: WidgetCircularAccessoryView(icon: .weatherSunsetUpIcon) { glyph in
                glyph
                    .border(Color.red, width: 2)
            }
        )
    }

    /// The scripts widget's container, at the circular family, with the model's control wrapped by
    /// `WidgetTileInteraction` exactly as on device.
    @available(iOS 18, *)
    @MainActor private func widget(_ model: WidgetBasicViewModel) -> some View {
        WidgetBasicContainerWrapperView(
            emptyViewGenerator: { AnyView(WidgetEmptyStateView(message: "Nothing configured yet")) },
            contents: [model],
            type: .button,
            widgetKind: .scripts,
            family: .accessoryCircular
        )
    }

    @available(iOS 18, *)
    @MainActor private func assertAccessory(
        of view: some View,
        named: String? = nil,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        assertSnapshot(
            // The lock screen is always light-on-dark, whatever the phone's appearance is.
            of: view
                .frame(width: Self.size.width, height: Self.size.height)
                .background(Color.black),
            layout: .fixed(width: Self.size.width, height: Self.size.height),
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
