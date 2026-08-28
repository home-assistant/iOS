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
    init() {
        Current.magicItemProvider = { MagicItemCustomizationMagicItemProvider() }
    }

    @Test func widgetOffersTapAndIconTapBehaviors() {
        assertLightDarkSnapshots(
            of: view(context: .widget, item: .init(id: "light.kitchen", serverId: "1", type: .entity)),
            drawHierarchyInKeyWindow: true
        )
    }

    /// The behavior that needs more than a name — a navigation path — brings its own row along, for
    /// either half of the tile.
    @Test func widgetShowsTheDetailsATapBehaviorNeeds() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .navigate("/lovelace/0")
        item.action = .moreInfoDialog
        assertLightDarkSnapshots(
            of: view(context: .widget, item: item),
            drawHierarchyInKeyWindow: true
        )
    }

    /// An app icon shortcut is a single action — there is no tile, so there is no second half.
    @Test func appIconShortcutKeepsASingleBehavior() {
        assertLightDarkSnapshots(
            of: view(context: .appIconShortcut, item: .init(id: "script.morning", serverId: "1", type: .script)),
            drawHierarchyInKeyWindow: true
        )
    }

    private func view(context: MagicItemAddView.Context, item: MagicItem) -> some View {
        NavigationView {
            MagicItemCustomizationView(mode: .edit, context: context, item: item) { _ in }
        }
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
