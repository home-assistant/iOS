@testable import HomeAssistant

import Shared
import Testing
import WidgetKit

/// What the entities widget shows for a given configuration, and how its tiles behave.
struct WidgetEntitiesTests {
    @available(iOS 17, *)
    @Test func configuredEntitiesBecomeItemsInPickOrder() {
        let configuration = Self.configuration(serverId: "1", entityIds: ["light.kitchen", "sensor.temperature"])

        let items = WidgetEntitiesTimelineProvider.items(for: configuration, family: .systemMedium)

        #expect(items == [
            MagicItem(id: "light.kitchen", serverId: "1", type: .entity),
            MagicItem(id: "sensor.temperature", serverId: "1", type: .entity),
        ])
    }

    /// The picker scopes its suggestions to the configured server, and a pick that predates a server
    /// change is dropped rather than drawn under the wrong server's name.
    @available(iOS 17, *)
    @Test func entitiesOfAnotherServerAreDropped() {
        let configuration = Self.configuration(serverId: "1", entityIds: ["light.kitchen"])
        configuration.entities?.append(Self.entity(serverId: "2", entityId: "light.office"))

        let items = WidgetEntitiesTimelineProvider.items(for: configuration, family: .systemMedium)

        #expect(items.map(\.id) == ["light.kitchen"])
    }

    @available(iOS 17, *)
    @Test func itemsAreCutToWhatTheFamilyHolds() {
        let entityIds = (0 ..< 20).map { "light.number_\($0)" }
        let configuration = Self.configuration(serverId: "1", entityIds: entityIds)

        for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge] {
            let items = WidgetEntitiesTimelineProvider.items(for: configuration, family: family)
            #expect(items.count == WidgetFamilySizes.size(for: family), "\(family)")
        }
    }

    @available(iOS 17, *)
    @Test func nothingPickedIsEmpty() {
        let configuration = WidgetEntitiesAppIntent()
        configuration.server = .init(identifier: .init(rawValue: "1"))
        configuration.entities = nil

        #expect(WidgetEntitiesTimelineProvider.items(for: configuration, family: .systemLarge).isEmpty)
    }

    /// The last update time is on unless the user switches it off; there is no switch for states.
    @available(iOS 17, *)
    @Test func lastUpdateTimeIsShownByDefault() {
        #expect(WidgetEntitiesAppIntent().showLastUpdateTime == true)
    }

    /// The gallery mock: a sample of entities with a state for each one that has one, and neither a
    /// server name nor an update time that could read as the user's own data.
    @available(iOS 17, *)
    @Test func previewEntryIsMockedFromTheSample() {
        for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] {
            let entry = WidgetEntitiesTimelineProvider.previewEntry(for: family)

            // The sample is a short, honest list rather than one padded to fill the largest family.
            let expectedCount = min(WidgetPreviewSample.entities.count, WidgetFamilySizes.sizeForPreview(for: family))
            #expect(entry.items.count == expectedCount, "\(family)")
            #expect(entry.items.allSatisfy { $0.serverId == WidgetPreviewSample.serverId }, "\(family)")
            #expect(entry.serverName == nil)
            #expect(entry.showLastUpdateTime == false)
            #expect(entry.magicItemInfoProvider is WidgetPreviewMagicItemProvider)
            for item in entry.items where item.domain != .scene && item.domain != .script {
                #expect(entry.entitiesState[item] != nil, "\(item.id) has no state in \(family)")
            }
        }
    }

    /// Two instances of the widget with different picks must not share a state cache, while the
    /// same picks in a different order do.
    @available(iOS 17, *)
    @Test func cacheIsPerSetOfEntities() {
        let kitchen = [MagicItem(id: "light.kitchen", serverId: "1", type: .entity)]
        let office = [MagicItem(id: "light.office", serverId: "1", type: .entity)]

        #expect(
            WidgetEntitiesTimelineProvider.cacheURL(serverId: "1", items: kitchen)
                == WidgetEntitiesTimelineProvider.cacheURL(serverId: "1", items: kitchen)
        )
        #expect(
            WidgetEntitiesTimelineProvider.cacheURL(serverId: "1", items: kitchen + office)
                == WidgetEntitiesTimelineProvider.cacheURL(serverId: "1", items: office + kitchen)
        )
        #expect(
            WidgetEntitiesTimelineProvider.cacheURL(serverId: "1", items: kitchen)
                != WidgetEntitiesTimelineProvider.cacheURL(serverId: "1", items: office)
        )
        #expect(
            WidgetEntitiesTimelineProvider.cacheURL(serverId: "1", items: kitchen)
                != WidgetEntitiesTimelineProvider.cacheURL(serverId: "2", items: kitchen)
        )
    }

    /// An entity the widget can act on is split: the icon runs the action and the rest opens it.
    @available(iOS 17, *)
    @Test func controllableTileSplitsIconAndBody() throws {
        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        let model = try #require(Self.models(for: [light]).first)

        #expect(
            model.iconInteractionType
                == .appIntent(.toggle(entityId: "light.kitchen", domain: "light", serverId: "1"))
        )
        #expect(model.interactionType == light.widgetTapInteractionType)
        #expect(model.showIconBackground)
    }

    /// A read-only entity opens in the app from anywhere on the tile, so it stays a single control.
    @available(iOS 17, *)
    @Test func readOnlyTileIsOneControl() throws {
        let sensor = MagicItem(id: "sensor.temperature", serverId: "1", type: .entity)
        let model = try #require(Self.models(for: [sensor]).first)

        #expect(model.iconInteractionType == nil)
        #expect(model.interactionType == sensor.widgetTapInteractionType)
        #expect(!model.showIconBackground)
    }

    /// States are always shown, so a state that arrived is the tile's subtitle.
    @available(iOS 17, *)
    @Test func stateIsTheSubtitle() throws {
        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        let state = WidgetEntityState(
            value: "On",
            domainState: .on,
            rawState: "on",
            deviceClass: nil,
            liveColorHex: nil,
            groupMemberDomain: nil
        )

        let model = try #require(Self.models(for: [light], states: [light: state]).first)

        #expect(model.subtitle == "On")
        #expect(model.title == "light.kitchen")
    }

    @available(iOS 17, *)
    private static func models(
        for items: [MagicItem],
        states: [MagicItem: WidgetEntityState] = [:]
    ) -> [WidgetBasicViewModel] {
        WidgetEntities().modelsForWidget(
            items: items,
            infoProvider: WidgetPreviewMagicItemProvider(),
            states: states
        )
    }

    @available(iOS 17, *)
    private static func configuration(serverId: String, entityIds: [String]) -> WidgetEntitiesAppIntent {
        let configuration = WidgetEntitiesAppIntent()
        configuration.server = .init(identifier: .init(rawValue: serverId))
        configuration.entities = entityIds.map { entity(serverId: serverId, entityId: $0) }
        return configuration
    }

    @available(iOS 17, *)
    private static func entity(serverId: String, entityId: String) -> WidgetEntitiesAppEntity {
        .init(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            displayString: entityId,
            icon: nil
        )
    }
}
