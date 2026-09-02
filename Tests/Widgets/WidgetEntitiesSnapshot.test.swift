@testable import HomeAssistant

import Shared
import SharedTesting

import SwiftUI
import Testing
import WidgetKit

/// The entities widget at every family it supports: user-picked entities drawn as tiles whose icon
/// controls the entity and whose body opens it, plus the mocked entry the widget gallery shows.
///
/// Rendered without the last update footer, so nothing in these images depends on the clock or the
/// time zone of the machine recording them.
struct WidgetEntitiesSnapshotTests {
    /// One of each shape a tile can take, in the order they appear on the widget.
    private static var items: [MagicItem] {
        [
            // Controllable: the icon toggles, the rest of the tile opens the entity.
            .init(id: "light.kitchen", serverId: "1", type: .entity),
            // Read-only: both halves open the entity, so the icon is not a control.
            .init(id: "sensor.temperature", serverId: "1", type: .entity),
            // No single main action, so it opens the entity too.
            .init(id: "lock.front_door", serverId: "1", type: .entity),
            // Controllable: activating a scene is something the widget does in place.
            .init(id: "scene.movie_night", serverId: "1", type: .entity),
            .init(id: "switch.porch", serverId: "1", type: .entity),
            .init(id: "cover.garage", serverId: "1", type: .entity),
            .init(id: "fan.bedroom", serverId: "1", type: .entity),
            .init(id: "media_player.living_room", serverId: "1", type: .entity),
            .init(id: "button.doorbell", serverId: "1", type: .entity),
            .init(id: "climate.hallway", serverId: "1", type: .entity),
            .init(id: "script.good_morning", serverId: "1", type: .entity),
            .init(id: "binary_sensor.motion", serverId: "1", type: .entity),
        ]
    }

    /// States are always shown on this widget, so every tile that has one carries it — and the
    /// icon takes the color the frontend gives that state.
    private static var states: [MagicItem: WidgetEntityState] {
        var states: [MagicItem: WidgetEntityState] = [:]
        for item in items {
            switch item.id {
            case "light.kitchen":
                states[item] = state("On", .on)
            case "sensor.temperature":
                states[item] = state("21.5 °C", nil, rawState: "21.5")
            case "lock.front_door":
                states[item] = state("Locked", .locked)
            case "switch.porch":
                states[item] = state("Off", .off)
            case "cover.garage":
                states[item] = state("Closed", .closed)
            case "fan.bedroom":
                states[item] = state("On", .on)
            case "media_player.living_room":
                states[item] = state("Playing", nil, rawState: "playing")
            case "climate.hallway":
                states[item] = state("Heat", nil, rawState: "heat")
            case "binary_sensor.motion":
                states[item] = state("Clear", .off)
            default:
                break
            }
        }
        return states
    }

    @available(iOS 18, *)
    @MainActor @Test func systemSmallSnapshot() {
        assertWidgetSnapshot(family: .systemSmall)
    }

    @available(iOS 18, *)
    @MainActor @Test func systemMediumSnapshot() {
        assertWidgetSnapshot(family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func systemLargeSnapshot() {
        assertWidgetSnapshot(family: .systemLarge)
    }

    @available(iOS 18, *)
    @MainActor @Test func systemExtraLargeSnapshot() {
        assertWidgetSnapshot(family: .systemExtraLarge)
    }

    /// A single controllable tile fills a small widget, the one arrangement that draws the icon
    /// above the title rather than beside it.
    @available(iOS 18, *)
    @MainActor @Test func singleControllableTileSnapshot() {
        assertWidgetSnapshot(
            items: [.init(id: "light.kitchen", serverId: "1", type: .entity)],
            family: .systemSmall,
            named: "controllable"
        )
    }

    /// A tile whose state has not arrived yet: the name stands alone and the icon keeps the app's
    /// tint instead of a state color.
    @available(iOS 18, *)
    @MainActor @Test func tilesWithoutStatesSnapshot() {
        assertWidgetSnapshot(
            items: Array(Self.items.prefix(4)),
            states: [:],
            family: .systemMedium,
            named: "noStates"
        )
    }

    /// Nothing picked yet, which is how the widget looks right after being added.
    @available(iOS 18, *)
    @MainActor @Test func emptySnapshot() {
        assertWidgetSnapshot(items: [], states: [:], family: .systemMedium, named: "empty")
    }

    /// The mocked entry shown while the user browses the widget gallery, at each family the gallery
    /// offers it in.
    @available(iOS 18, *)
    @MainActor @Test func previewSystemSmallSnapshot() {
        assertPreviewSnapshot(family: .systemSmall)
    }

    @available(iOS 18, *)
    @MainActor @Test func previewSystemMediumSnapshot() {
        assertPreviewSnapshot(family: .systemMedium)
    }

    @available(iOS 18, *)
    @MainActor @Test func previewSystemLargeSnapshot() {
        assertPreviewSnapshot(family: .systemLarge)
    }

    @available(iOS 18, *)
    @MainActor @Test func previewSystemExtraLargeSnapshot() {
        assertPreviewSnapshot(family: .systemExtraLarge)
    }

    @available(iOS 18, *)
    @MainActor private func assertPreviewSnapshot(
        family: WidgetFamily,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let entry = WidgetEntitiesTimelineProvider.previewEntry(for: family)
        let models = WidgetEntities().modelsForWidget(
            items: entry.items,
            infoProvider: entry.magicItemInfoProvider,
            states: entry.entitiesState
        )
        let size = Self.size(for: family)
        assertLightDarkSnapshots(
            of: Self.widgetView(models: models, family: family),
            layout: .fixed(width: size.width, height: size.height),
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    @available(iOS 18, *)
    @MainActor private func assertWidgetSnapshot(
        items: [MagicItem] = WidgetEntitiesSnapshotTests.items,
        states: [MagicItem: WidgetEntityState] = WidgetEntitiesSnapshotTests.states,
        family: WidgetFamily,
        named: String? = nil,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let size = Self.size(for: family)
        let shown = Array(items.prefix(WidgetFamilySizes.size(for: family)))
        let models = WidgetEntities().modelsForWidget(
            items: shown,
            infoProvider: WidgetEntitiesSnapshotMagicItemProvider(),
            states: states
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
            emptyViewGenerator: { AnyView(WidgetEmptyStateView(message: L10n.Widgets.Entities.notConfigured)) },
            contents: models,
            type: .custom,
            widgetKind: .entities,
            family: family
        )
        .environment(\.widgetFamily, family)
    }

    private static func state(
        _ value: String,
        _ domainState: Domain.State?,
        rawState: String? = nil
    ) -> WidgetEntityState {
        .init(
            value: value,
            domainState: domainState,
            rawState: rawState ?? domainState?.rawValue ?? EntityStateActive.unknown,
            deviceClass: nil,
            liveColorHex: nil,
            groupMemberDomain: nil
        )
    }

    private static func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: CGSize(width: 160, height: 160)
        case .systemMedium: CGSize(width: 350, height: 160)
        case .systemLarge: CGSize(width: 350, height: 310)
        default: CGSize(width: 720, height: 310)
        }
    }
}

/// Names, icons and areas for the entities the tiles are drawn from, so the snapshots read as a
/// home rather than as a column of entity ids.
private final class WidgetEntitiesSnapshotMagicItemProvider: MagicItemProviderProtocol {
    private static let info: [String: (name: String, icon: String, area: String?)] = [
        "light.kitchen": ("Kitchen light", "mdi:lightbulb", "Kitchen"),
        "sensor.temperature": ("Temperature", "mdi:thermometer", "Living room"),
        "lock.front_door": ("Front door", "mdi:lock", "Entrance"),
        "scene.movie_night": ("Movie night", "mdi:movie-open", nil),
        "switch.porch": ("Porch", "mdi:toggle-switch", "Garden"),
        "cover.garage": ("Garage", "mdi:garage", "Garage"),
        "fan.bedroom": ("Fan", "mdi:fan", "Bedroom"),
        "media_player.living_room": ("TV", "mdi:television", "Living room"),
        "button.doorbell": ("Doorbell", "mdi:bell", "Entrance"),
        "climate.hallway": ("Thermostat", "mdi:thermostat", "Hallway"),
        "script.good_morning": ("Good morning", "mdi:weather-sunset-up", nil),
        "binary_sensor.motion": ("Motion", "mdi:motion-sensor", "Hallway"),
    ]

    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        let info = Self.info[item.id] ?? (name: item.id, icon: "mdi:dots-grid", area: nil)
        return .init(id: item.serverUniqueId, name: info.name, iconName: info.icon)
    }

    func getAreaName(for item: MagicItem) -> String? {
        Self.info[item.id]?.area
    }
}
