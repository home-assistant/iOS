@testable import HomeAssistant

import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

/// The tiles the custom and entities widgets draw: each tap behavior a tile can have (a link, an
/// intent, a confirmation first), the view models built from a stored widget, and the widget
/// configurations themselves.
///
/// `.isolatedEnvironment`: the servers, API cache and database the entities widget reads are
/// installed per test; rendering runs on the main actor.
@Suite(.isolatedEnvironment)
struct WidgetTileRenderingTests {
    // MARK: - Tap behaviors

    /// Every way a tile can respond to a tap draws: a confirmation waiting on a link or an intent,
    /// a link or an intent that must be confirmed first, a tile split between icon and body, and
    /// each intent a tap can run.
    @available(iOS 17, *)
    @Test @MainActor func everyTapBehaviorDraws() {
        let link = URL(string: "https://example.com/page")!
        let moreInfo = AppConstants.openEntityDestinationURL(entityId: "light.a", serverId: "s")
            ?? link
        let intents: [WidgetIntentType] = [
            .toggle(entityId: "light.a", domain: "light", serverId: "s"),
            .activate(entityId: "scene.a", domain: "scene", serverId: "s"),
            .script(id: "script.a", entityId: "script.a", serverId: "s", name: "A", showConfirmationNotification: true),
            .performAction(serverId: "s", actionId: "light.turn_on", payload: "{}"),
            .refresh,
        ]
        var models: [WidgetBasicViewModel] = [
            Self.model(interaction: .widgetURL(link), showConfirmation: true),
            Self.model(interaction: .appIntent(intents[0]), showConfirmation: true),
            Self.model(interaction: .appIntent(.refresh), showConfirmation: true, confirmsTapAction: true),
            Self.model(interaction: .widgetURL(link), requiresConfirmation: true),
            Self.model(interaction: .widgetURL(moreInfo), requiresConfirmation: true),
            Self.model(interaction: .widgetURL(link)),
            Self.model(interaction: .widgetURL(moreInfo), icon: .appIntent(intents[0]), requiresConfirmation: true),
            Self.model(interaction: .widgetURL(link), icon: .appIntent(intents[1])),
            Self.model(interaction: .appIntent(intents[2]), icon: .widgetURL(link)),
        ]
        models += intents.map { Self.model(interaction: .appIntent($0)) }
        models += intents.map { Self.model(interaction: .appIntent($0), requiresConfirmation: true) }
        for isSplit in [false, true] {
            var optimistic = Self.model(
                interaction: isSplit ? .widgetURL(moreInfo) : .appIntent(intents[0]),
                icon: isSplit ? .appIntent(intents[0]) : nil
            )
            optimistic.optimisticToggle = .init(domain: .light, state: .init(
                value: "Off",
                domainState: .off,
                rawState: "off",
                deviceClass: nil,
                liveColorHex: nil,
                groupMemberDomain: nil
            ))
            models.append(optimistic)
        }

        for model in models {
            render(WidgetBasicContainerView(
                emptyViewGenerator: { AnyView(Text(verbatim: "Empty")) },
                contents: [model],
                type: .custom,
                showLastUpdate: true,
                showServerName: true,
                serverName: "Home",
                widgetKind: .custom
            ))
        }
        render(WidgetBasicContainerView(
            emptyViewGenerator: { AnyView(Text(verbatim: "Empty")) },
            contents: [],
            type: .button,
            widgetKind: .custom
        ))
        render(WidgetRefreshButton(kind: .custom, date: Date()))
    }

    @available(iOS 17, *)
    @Test @MainActor func refreshControlsDrawWhileWaitingForTheirIntents() {
        let date = Date(timeIntervalSince1970: 0)
        render(WidgetCalendarRefreshButton(date: date))
        render(WidgetEnergyControls.period("Today")(AnyView(Text(verbatim: "Today"))))
        render(WidgetEnergyControls.refresh(date)(AnyView(Text(verbatim: "Updated"))))
        for entry in [
            WidgetEnergyEntry(isConfigured: true, loadFailed: true),
            WidgetEnergyEntry(isConfigured: false, noConnection: true),
        ] {
            render(WidgetEnergyView(entry: entry))
        }
    }

    // MARK: - Custom widget models

    /// A stored widget's tiles take their colors and names from the item's customization and info;
    /// a tile waiting on a confirmation is greyed out, and one without info shows its entity id.
    @available(iOS 17, *)
    @Test @MainActor func customWidgetTilesFollowTheirCustomization() {
        let customized = MagicItem(
            id: "light.one",
            serverId: "s",
            type: .entity,
            customization: .init(iconColor: "#FF0000", textColor: "#FFFFFF", backgroundColor: "#000000")
        )
        let plain = MagicItem(id: "script.two", serverId: "s", type: .script)
        let state = WidgetEntityState(
            value: "On",
            domainState: .on,
            rawState: "on",
            deviceClass: nil,
            liveColorHex: "#00FF00",
            groupMemberDomain: nil
        )
        let widget = CustomWidget(id: "w", name: "W", items: [customized, plain])
        let custom = WidgetCustom()

        #expect(
            custom.modelsForWidget(nil, infoProvider: MockMagicItemProvider(), states: [:], showStates: true)
                .isEmpty
        )
        let models = custom.modelsForWidget(
            widget,
            infoProvider: MockMagicItemProvider(),
            states: [customized: state],
            showStates: true
        )
        #expect(models.map(\.title) == ["Abc", "Cba"])
        #expect(models.first?.useCustomColors == true)

        let unnamed = custom.modelsForWidget(
            widget,
            infoProvider: EmptyInfoProvider(),
            states: [:],
            showStates: false
        )
        #expect(unnamed.map(\.title) == ["light.one", "script.two"])

        var pending = widget
        pending.itemsStates = [customized.serverUniqueId: .pendingConfirmation]
        let confirming = custom.modelsForWidget(
            pending,
            infoProvider: MockMagicItemProvider(),
            states: [customized: state],
            showStates: true
        )
        #expect(confirming.count == 2)
        for model in models + confirming {
            render(WidgetBasicContainerView(
                emptyViewGenerator: { AnyView(EmptyView()) },
                contents: [model],
                type: .custom,
                widgetKind: .custom
            ))
        }
        _ = custom.body
        _ = WidgetCommonlyUsedEntities().body
        _ = WidgetGauge().body
        _ = WidgetCalendar().body
        _ = WidgetTodoList().body
        _ = WidgetEnergy().body
        _ = WidgetEntities().body
    }

    @available(iOS 18, *)
    @Test func controlWidgetsDescribeThemselves() {
        _ = ControlOpenCamera().body
        _ = ControlOpenEntity().body
        _ = ControlOpenPage().body
    }

    // MARK: - Entities widget

    /// The entities widget fetches a state for each picked entity and caches it per selection.
    @available(iOS 17, *)
    @Test func theEntitiesWidgetFetchesItsPicksStates() async throws {
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "entities-\(UUID().uuidString)"), serverInfo: .fake())
        Current.servers = servers
        Current.magicItemProvider = { WidgetPreviewMagicItemProvider() }
        let database = try SettingsTestDatabase.make()
        Current.database = { database }
        let connection = WidgetStubConnection { request in
            request.type.command == "states/sensor.power"
                ? .success(HAData(value: ["state": "5", "attributes": ["unit_of_measurement": "W"]]))
                : .success(HAData(value: ["state": "on", "attributes": [String: Any]()]))
        }
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)

        let serverId = server.identifier.rawValue
        let configuration = WidgetEntitiesAppIntent()
        configuration.server = .init(identifier: server.identifier)
        configuration.entities = ["sensor.power", "light.kitchen"].map {
            .init(id: "\(serverId)-\($0)", entityId: $0, serverId: serverId, displayString: $0)
        }
        configuration.showLastUpdateTime = true
        let items = WidgetEntitiesTimelineProvider.items(for: configuration, family: .systemMedium)
        let cacheURL = WidgetEntitiesTimelineProvider.cacheURL(serverId: serverId, items: items)
        defer { try? FileManager.default.removeItem(at: cacheURL) }

        let entry = await WidgetEntitiesTimelineProvider().timelineEntry(for: configuration, family: .systemMedium)
        #expect(entry.entitiesState.count == 2)
        #expect(entry.entitiesState.first { $0.key.id == "sensor.power" }?.value.value == "5 W")
        #expect(WidgetEntitiesConstants.expiration.converted(to: .minutes).value == 15)
        #expect(WidgetEntitiesTimelineProvider().expiration.converted(to: .minutes).value == 15)
    }

    // MARK: - Live Activity colors

    @Test func liveActivityColorsResolveFromTheirHex() {
        #expect(HAActivityVisualStyle.backgroundColor(from: nil) == .clear)
        #expect(HAActivityVisualStyle.backgroundColor(from: "  ") == .clear)
        _ = HAActivityVisualStyle.backgroundColor(from: "#112233")
        _ = HAActivityVisualStyle.supplementalBackgroundColor(from: nil)
        _ = HAActivityVisualStyle.supplementalBackgroundColor(from: "#FFFFFF")
        _ = HAActivityVisualStyle.color(from: nil)
        #expect(HAActivityVisualStyle.prefersLightText(onBackground: "#000000"))
        #expect(!HAActivityVisualStyle.prefersLightText(onBackground: "#FFFFFF"))
        #expect(HAActivityVisualStyle.foregroundColor(textColor: "#FF0000", onBackground: nil) != nil)
        #expect(HAActivityVisualStyle.foregroundColor(textColor: nil, onBackground: nil) == nil)
        #expect(HAActivityVisualStyle.foregroundColor(textColor: nil, onBackground: "#000000") == .white)
        #expect(HAActivityVisualStyle.foregroundColor(textColor: nil, onBackground: "#FFFFFF") == .black)
        #expect(HAActivityVisualStyle.foregroundColor(textColor: nil, onBackground: "#00000000") == nil)
    }

    // MARK: - Entity details

    /// An entity's area and device are read from the stored registries; a database that can't be
    /// read gives neither.
    @Test func anEntitysAreaAndDeviceComeFromTheRegistries() throws {
        let entity = HAAppEntity(
            id: "s-light.a",
            entityId: "light.a",
            serverId: "s",
            domain: "light",
            name: "A",
            icon: nil,
            rawDeviceClass: nil
        )
        let database = try SettingsTestDatabase.make()
        Current.database = { database }
        #expect(entity.area == nil)
        #expect(entity.device == nil)

        let broken = try DatabaseQueue()
        Current.database = { broken }
        #expect(entity.area == nil)
        #expect(entity.device == nil)
    }

    // MARK: - Helpers

    private static func model(
        interaction: WidgetInteractionType,
        icon: WidgetInteractionType? = nil,
        showConfirmation: Bool = false,
        confirmsTapAction: Bool = false,
        requiresConfirmation: Bool = false
    ) -> WidgetBasicViewModel {
        WidgetBasicViewModel(
            id: UUID().uuidString,
            title: "Tile",
            subtitle: "On",
            area: "Kitchen",
            interactionType: interaction,
            iconInteractionType: icon,
            icon: .lightbulbIcon,
            showConfirmation: showConfirmation,
            confirmsTapAction: confirmsTapAction,
            requiresConfirmation: requiresConfirmation,
            widgetId: "w"
        )
    }

    @MainActor
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 170, height: 170))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    private final class EmptyInfoProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] { [:] }

        func getInfo(for item: MagicItem) -> MagicItem.Info? { nil }

        func getAreaName(for item: MagicItem) -> String? { nil }
    }
}
