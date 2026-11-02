@testable import HomeAssistant

import AppIntents
import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing
import WidgetKit

/// The pickers and values behind the Control Center "open" controls, the page, icon, sensor, action
/// and camera pickers, and the item sizes each widget family is configured with.
///
/// `.isolatedEnvironment`: the database and servers the pickers read are installed per test.
@Suite(.isolatedEnvironment)
struct WidgetEntityPickersTests {
    // MARK: - Pages

    @Test func thePagePickerListsEachServersPanels() async throws {
        let servers = FakeServerManager()
        let home = servers.add(identifier: .init(rawValue: "home"), serverInfo: .fake())
        Current.servers = servers
        let database = try SettingsTestDatabase.make()
        try await database.write { db in
            try AppPanel(serverId: "home", title: "Energy", path: "energy", component: "energy", showInSidebar: true)
                .insert(db)
            try AppPanel(
                serverId: "home",
                icon: "mdi:map",
                title: "Map",
                path: "map",
                component: "map",
                showInSidebar: true
            )
            .insert(db)
        }
        Current.database = { database }
        let query = PageAppEntityQuery()

        let suggested = try await query.suggestedEntities()
        #expect(suggested.sections.flatMap(\.items).count == 2)
        let matching = try await query.entities(matching: "ENER")
        #expect(matching.sections.flatMap(\.items).map(\.value.panel.title) == ["Energy"])
        let byId = try await query.entities(for: [PageAppEntity.makeId(serverId: "home", panelPath: "map")])
        #expect(byId.map(\.panel.path) == ["map"])
        #expect(byId.first?.serverId == home.identifier.rawValue)
        #expect(!String(describing: byId[0].displayRepresentation.title).isEmpty)
    }

    @available(iOS 18, *)
    @Test func openingAPageNeedsAServer() async throws {
        Current.servers = FakeServerManager()
        let intent = OpenPageAppIntent()
        intent.page = nil
        _ = try await intent.perform()
        intent.page = PageAppEntity(
            id: "x",
            panel: .init(icon: nil, title: "Map", path: "map", component: "map", showInSidebar: true),
            serverId: "gone"
        )
        _ = try await intent.perform()
    }

    // MARK: - Control values

    /// Each "open" control shows its configured target, or a placeholder until one is picked.
    @available(iOS 18, *)
    @Test func openControlsShowTheirTargetOrAPlaceholder() async throws {
        let entity = HAAppEntityAppIntentEntity(
            id: "s-camera.door",
            entityId: "camera.door",
            serverId: "s",
            serverName: "Home",
            displayString: "Door",
            iconName: "camera"
        )
        let icon = SFSymbolEntity(id: "video")

        let cameraConfiguration = ControlOpenCameraConfiguration()
        let cameraProvider = ControlOpenCameraValueProvider()
        #expect(cameraProvider.placeholder(for: cameraConfiguration).entity.entityId.isEmpty)
        cameraConfiguration.entity = entity
        cameraConfiguration.icon = icon
        cameraConfiguration.displayText = "Front door"
        let camera = try await cameraProvider.currentValue(configuration: cameraConfiguration)
        #expect(camera.entity.entityId == "camera.door")
        #expect(cameraProvider.previewValue(configuration: cameraConfiguration).displayText == "Front door")

        let entityConfiguration = ControlOpenEntityConfiguration()
        let entityProvider = ControlOpenEntityValueProvider()
        #expect(entityProvider.previewValue(configuration: entityConfiguration).icon.id == "rectangle.and.paperclip")
        entityConfiguration.entity = entity
        entityConfiguration.icon = icon
        let opened = try await entityProvider.currentValue(configuration: entityConfiguration)
        #expect(opened.entity.entityId == "camera.door")
        #expect(entityProvider.placeholder(for: entityConfiguration).icon.id == "video")

        let pageConfiguration = ControlOpenPageConfiguration()
        let pageProvider = ControlOpenPageValueProvider()
        #expect(pageProvider.placeholder(for: pageConfiguration).page.panel.path.isEmpty)
        pageConfiguration.page = PageAppEntity(
            id: "s-map",
            panel: .init(icon: nil, title: "Map", path: "map", component: "map", showInSidebar: true),
            serverId: "s"
        )
        pageConfiguration.icon = icon
        let page = try await pageProvider.currentValue(configuration: pageConfiguration)
        #expect(page.page.panel.path == "map")
        #expect(pageProvider.previewValue(configuration: pageConfiguration).icon.id == "video")
    }

    // MARK: - Icons

    @Test func theIconPickerSearchesTheSymbols() async throws {
        let query = IntentSFSymbolAppEntityQuery()
        let suggested = try await query.suggestedEntities()
        #expect(suggested.sections.flatMap(\.items).count == 100)
        let all = try await query.entities(for: [])
        #expect(all.count == 100)
        let picked = try await query.entities(for: ["lightbulb", "not.a.symbol"])
        #expect(picked.map(\.id) == ["lightbulb"])
        let matching = try await query.entities(matching: "LIGHTBULB")
        #expect(matching.sections.flatMap(\.items).map(\.value.id).contains("lightbulb"))
        #expect(!String(describing: picked[0].displayRepresentation.title).isEmpty)
    }

    // MARK: - Sensors and entities

    @available(iOS 17, *)
    @Test func theSensorPickerListsSensorsPerServer() async throws {
        let servers = FakeServerManager()
        _ = servers.add(identifier: .init(rawValue: "home"), serverInfo: .fake())
        Current.servers = servers
        let database = try SettingsTestDatabase.make()
        try await database.write { db in
            try HAAppEntity(
                id: "home-sensor.power",
                entityId: "sensor.power",
                serverId: "home",
                domain: "sensor",
                name: "Power",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
        }
        Current.database = { database }
        let query = IntentSensorsAppEntityQuery()

        let suggested = try await query.suggestedEntities()
        #expect(suggested.sections.flatMap(\.items).map(\.value.entityId) == ["sensor.power"])
        let byId = try await query.entities(for: ["home-sensor.power"])
        #expect(byId.map(\.displayString) == ["Power"])
        _ = byId.first?.displayRepresentation
        let defaultResult = await query.defaultResult()
        #expect(defaultResult?.entityId == "sensor.power")

        let collection = makeHAEntityIntentItemCollection(
            entities: [(servers.all[0], [HAAppEntity(
                id: "home-light.a",
                entityId: "light.a",
                serverId: "home",
                domain: "light",
                name: "A",
                icon: nil,
                rawDeviceClass: nil
            )])],
            defaultIconName: "lightbulb"
        )
        let item = try #require(collection.sections.first?.items.first?.value)
        #expect(item.iconName == "lightbulb")
        _ = item.displayRepresentation
    }

    @Test func entitiesDescribeWhereTheyLive() {
        let withServer = HAAppEntityAppIntentEntity(
            id: "home-light.a",
            entityId: "light.a",
            serverId: "home",
            serverName: "Home",
            areaName: "Kitchen",
            floorName: "Ground",
            displayString: "Ceiling",
            iconName: "lightbulb",
            includesServerContext: true
        )
        #expect(withServer.subtitle?.isEmpty == false)
        _ = withServer.displayRepresentation

        let unknownDomain = HAAppEntityAppIntentEntity(
            id: "home-future.a",
            entityId: "future.a",
            serverId: "home",
            serverName: "Home",
            displayString: "Future",
            iconName: ""
        )
        _ = unknownDomain.displayRepresentation
        #expect(HAAppEntityAppIntentEntity.fallbackSymbolName == "power.circle")
    }

    // MARK: - Actions and cameras

    /// Without the server the shortcut picked there is nothing to list, but a stored identifier
    /// still resolves so a saved shortcut keeps working.
    @available(iOS 17, *)
    @Test func actionAndCameraPickersResolveStoredIdentifiers() async throws {
        let actions = IntentActionEntityQuery()
        let suggestedActions = try await actions.suggestedEntities()
        #expect(suggestedActions.sections.isEmpty)
        let matchingActions = try await actions.entities(matching: "light")
        #expect(matchingActions.sections.isEmpty)
        let storedActions = try await actions.entities(for: ["home::light.turn_on", "broken"])
        #expect(storedActions.map(\.actionId) == ["light.turn_on"])

        let cameras = IntentCameraEntityQuery()
        let suggestedCameras = try await cameras.suggestedEntities()
        #expect(suggestedCameras.sections.isEmpty)
        let matchingCameras = try await cameras.entities(matching: "door")
        #expect(matchingCameras.sections.isEmpty)
        let storedCameras = try await cameras.entities(for: ["home::camera.door", "broken"])
        #expect(storedCameras.map(\.entityId) == ["camera.door"])
        _ = storedCameras.first?.displayRepresentation

        let described = IntentActionEntity(serverId: "home", definition: IntentActionDefinition(
            domain: "light",
            service: "turn_on",
            name: "Turn on",
            actionDescription: "Turns lights on",
            icon: "mdi:lightbulb-on",
            supportsResponse: true
        ))
        #expect(described.id == "home::light.turn_on")
        #expect(described.supportsResponse)
        _ = described.displayRepresentation
        let plain = IntentActionEntity(serverId: "home", definition: IntentActionDefinition(
            domain: "script",
            service: "run",
            name: nil,
            actionDescription: nil
        ))
        _ = plain.displayRepresentation
    }

    // MARK: - Family sizes

    @available(iOS 17, *)
    @Test func everyFamilyHasItsSizes() {
        let families: [WidgetFamily] = [
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ]
        for family in families {
            _ = WidgetFamilySizes.intentCollectionSize(for: family)
            #expect(WidgetFamilySizes.todoListSize(for: family) >= 0)
            #expect(WidgetFamilySizes.compactSizeBreakpoint(for: family) >= 0)
            #expect(WidgetFamilySizes.compressedBreakpoint(for: family) >= 0)
            #expect(WidgetFamilySizes.calendarSize(for: family) >= 0)
        }
    }
}
