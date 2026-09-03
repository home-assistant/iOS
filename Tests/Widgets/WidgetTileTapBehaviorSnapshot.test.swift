@testable import HomeAssistant

import Shared
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// The tiles the custom and commonly-used-entities widgets draw once the icon became a control of
/// its own: an entity the widget can act on keeps its icon background, and anything that only opens
/// the app — a sensor, a lock, a script left on its default, an item told to navigate — draws its
/// icon plain.
struct WidgetTileTapBehaviorSnapshotTests {
    /// One of each shape a tile can take, in the order they appear on the widget.
    private static var items: [MagicItem] {
        [
            // Controllable: the icon toggles, the rest of the tile opens the entity.
            .init(id: "light.kitchen", serverId: "1", type: .entity),
            // Read-only: both halves open the entity, so the icon is not a control.
            .init(id: "sensor.temperature", serverId: "1", type: .entity),
            // A lock's icon unlocks or locks it by state, and always confirms before it runs.
            .init(id: "lock.front_door", serverId: "1", type: .entity),
            // A script's icon runs it.
            .init(id: "script.morning", serverId: "1", type: .script),
            // Told to open a dashboard instead, which leaves nothing to control.
            .init(
                id: "cover.garage",
                serverId: "1",
                type: .entity,
                action: .navigate("/lovelace/0")
            ),
            // Told only to open the entity, though it could toggle.
            .init(id: "switch.porch", serverId: "1", type: .entity, action: .moreInfoDialog),
        ]
    }

    @available(iOS 18, *)
    @MainActor @Test func customWidgetSystemSmallSnapshot() {
        assertCustomWidgetSnapshot(family: .systemSmall)
    }

    @available(iOS 18, *)
    @MainActor @Test func customWidgetSystemMediumSnapshot() {
        assertCustomWidgetSnapshot(family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func customWidgetSystemLargeSnapshot() {
        assertCustomWidgetSnapshot(family: .systemLarge)
    }

    /// A single tile fills a small widget, which is the only size style that draws the icon above
    /// the title rather than beside it — the other arrangement the split has to leave untouched.
    @available(iOS 18, *)
    @MainActor @Test func customWidgetSingleControllableTileSnapshot() {
        assertCustomWidgetSnapshot(
            items: [.init(id: "light.kitchen", serverId: "1", type: .entity)],
            family: .systemSmall,
            named: "controllable"
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func customWidgetSingleReadOnlyTileSnapshot() {
        assertCustomWidgetSnapshot(
            items: [.init(id: "sensor.temperature", serverId: "1", type: .entity)],
            family: .systemSmall,
            named: "readOnly"
        )
    }

    /// A tile waiting on its confirmation is not split — the form stands in for the whole tile, and
    /// the rest of the widget dims behind it.
    @available(iOS 18, *)
    @MainActor @Test func customWidgetPendingConfirmationSnapshot() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.customization = .init(requiresConfirmation: true)
        assertCustomWidgetSnapshot(
            items: [item, .init(id: "script.morning", serverId: "1", type: .script)],
            itemsStates: ["1-light.kitchen": .pendingConfirmation],
            family: .systemMedium,
            named: "pendingConfirmation"
        )
    }

    /// The rest of a split tile asks for confirmation too when its behavior runs something — here a
    /// lock told to lock on tap — and the form it turns into looks the same as the icon's.
    @available(iOS 18, *)
    @MainActor @Test func customWidgetPendingTapConfirmationSnapshot() {
        var item = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)
        item.action = .toggle
        item.tapAction = .turnOff
        item.customization = .init(requiresConfirmation: true)
        assertCustomWidgetSnapshot(
            items: [item, .init(id: "light.kitchen", serverId: "1", type: .entity)],
            itemsStates: ["1-lock.front_door": .pendingTapConfirmation],
            family: .systemMedium,
            named: "pendingTapConfirmation"
        )
    }

    @available(iOS 18, *)
    @MainActor @Test func commonlyUsedEntitiesSystemMediumSnapshot() {
        let size = Self.size(for: .systemMedium)
        let models = WidgetCommonlyUsedEntities().modelsForWidget(
            items: Self.items,
            infoProvider: WidgetTileTapBehaviorMagicItemProvider(),
            states: [:],
            showStates: false
        )
        assertLightDarkSnapshots(
            of: Self.widgetView(models: models, family: .systemMedium),
            layout: .fixed(width: size.width, height: size.height)
        )
    }

    @available(iOS 18, *)
    @MainActor private func assertCustomWidgetSnapshot(
        items: [MagicItem] = WidgetTileTapBehaviorSnapshotTests.items,
        itemsStates: [String: CustomWidget.ItemState] = [:],
        family: WidgetFamily,
        named: String? = nil,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = Self.size(for: family)
        let widget = CustomWidget(id: "widget-1", name: "Tiles", items: items, itemsStates: itemsStates)
        let models = WidgetCustom().modelsForWidget(
            widget,
            infoProvider: WidgetTileTapBehaviorMagicItemProvider(),
            states: [:],
            showStates: false
        )
        assertLightDarkSnapshots(
            of: Self.widgetView(models: models, family: family),
            layout: .fixed(width: size.width, height: size.height),
            named: named,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    @available(iOS 18, *)
    @MainActor private static func widgetView(models: [WidgetBasicViewModel], family: WidgetFamily) -> some View {
        WidgetBasicContainerWrapperView(
            emptyViewGenerator: { AnyView(EmptyView()) },
            contents: models,
            type: .custom,
            widgetKind: .custom,
            family: family
        )
        .environment(\.widgetFamily, family)
    }

    private static func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: CGSize(width: 160, height: 160)
        case .systemMedium: CGSize(width: 350, height: 160)
        default: CGSize(width: 350, height: 310)
        }
    }
}

/// Names and icons for the entities the tiles are drawn from, so the snapshots read as a home
/// rather than as a column of entity ids.
private final class WidgetTileTapBehaviorMagicItemProvider: MagicItemProviderProtocol {
    private static let info: [String: (name: String, icon: String)] = [
        "light.kitchen": ("Kitchen light", "mdi:lightbulb"),
        "sensor.temperature": ("Temperature", "mdi:thermometer"),
        "lock.front_door": ("Front door", "mdi:lock"),
        "script.morning": ("Good morning", "mdi:weather-sunset-up"),
        "cover.garage": ("Garage", "mdi:garage"),
        "switch.porch": ("Porch", "mdi:toggle-switch"),
    ]

    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        let info = Self.info[item.id] ?? (name: item.id, icon: "mdi:dots-grid")
        return .init(id: item.serverUniqueId, name: info.name, iconName: info.icon)
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
