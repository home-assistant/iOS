@testable import HomeAssistant

import Shared
import SharedTesting

import SwiftUI
import Testing

/// A widget tile is tapped in two places now, so its customization screen offers two behaviors: what
/// a tap on the tile does, and what a tap on its icon does. Everywhere else a magic item is used
/// there is still only one thing to tap.
@MainActor
struct MagicItemCustomizationViewTests {
    @Test func widgetOffersTapAndIconTapBehaviors() {
        assertSnapshots(context: .widget, item: .init(id: "light.kitchen", serverId: "1", type: .entity))
    }

    /// The behavior that needs more than a name — a navigation path — brings its own row along, for
    /// either half of the tile.
    @Test func widgetShowsTheDetailsATapBehaviorNeeds() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .navigate("/lovelace/0")
        item.action = .moreInfoDialog
        assertSnapshots(context: .widget, item: item)
    }

    /// An app icon shortcut is a single action — there is no tile, so there is no second half.
    @Test func appIconShortcutKeepsASingleBehavior() {
        assertSnapshots(
            context: .appIconShortcut,
            item: .init(id: "script.morning", serverId: "1", type: .script)
        )
    }

    /// "Perform action" needs two things a name can't carry: which action to call, and the data to
    /// send with it. With no server reachable the picker reads the stored id as a name — never the
    /// raw `domain.service` pair — which is what the screen shows before the servers answer.
    @Test func widgetShowsThePerformActionRows() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.action = .performAction("1", "light.turn_on", "{\"brightness_pct\": 60}")
        assertSnapshots(context: .widget, item: item)
    }

    /// An action chosen but not yet given any data leaves the payload field on its placeholder, with
    /// the footer explaining what belongs there.
    @Test func widgetShowsThePerformActionRowsWithoutData() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.action = .performAction("1", "light.toggle", "")
        assertSnapshots(context: .widget, item: item)
    }

    /// The one behavior that points outside Home Assistant brings a single field along.
    @Test func widgetShowsTheUrlRow() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .url("https://www.home-assistant.io/docs")
        assertSnapshots(context: .widget, item: item)
    }

    /// A shortcut has one behavior, so "perform action" fills the whole section on its own.
    @Test func appIconShortcutShowsThePerformActionRows() {
        var item = MagicItem(id: "script.morning", serverId: "1", type: .script)
        item.action = .performAction("1", "notify.persistent_notification", "{\"message\": \"Good morning\"}")
        assertSnapshots(context: .appIconShortcut, item: item)
    }

    /// A behavior that needs nothing else — the frontend's "toggle" — adds no rows, so the section
    /// stays as short as the default does.
    @Test func widgetShowsNoExtraRowsForToggle() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .toggle
        item.action = .toggle
        assertSnapshots(context: .widget, item: item)
    }

    /// `Current` is a shared global, so the mocked provider is put back as soon as the snapshot is
    /// taken — left in place it would follow whichever suite runs next.
    private func assertSnapshots(
        context: MagicItemAddView.Context,
        item: MagicItem,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let previousProvider = Current.magicItemProvider
        Current.magicItemProvider = { MagicItemCustomizationMagicItemProvider() }
        defer { Current.magicItemProvider = previousProvider }

        assertLightDarkSnapshots(
            of: NavigationView {
                MagicItemCustomizationView(mode: .edit, context: context, item: item) { _ in }
            },
            drawHierarchyInKeyWindow: true,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}

private final class MagicItemCustomizationMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(id: item.serverUniqueId, name: "Kitchen light", iconName: "mdi:lightbulb")
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
