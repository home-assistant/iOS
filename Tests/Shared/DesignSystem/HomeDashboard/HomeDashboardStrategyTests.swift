@testable import Shared
import Testing

/// The translator itself: given the registries a server would report, does it produce the screens
/// the web frontend's home strategy produces?
struct HomeDashboardStrategyTests {
    private let registry = HomeDashboardSampleHome.registry

    private func dashboard() -> HomeDashboardConfig {
        HomeDashboardStrategy.generate(config: HomeDashboardSampleHome.strategyConfig, registry: registry)
    }

    // MARK: - The dashboard as a whole

    @Test func generatesAnOverviewFollowedByOneViewPerArea() {
        let views = dashboard().views
        #expect(views.first?.path == "overview")
        #expect(views.dropFirst().map(\.path) == [
            "areas-living_room",
            "areas-kitchen",
            "areas-bedroom",
            "areas-bathroom",
            "areas-garage",
        ])
        // Counted rather than `allSatisfy`, which SwiftFormat rewrites to a key path that `#expect`
        // then refuses to expand.
        let subviews = views.dropFirst().filter(\.isSubview)
        #expect(subviews.count == views.count - 1)
    }

    @Test func areaViewsAreTitledAndIconedByTheirArea() {
        let kitchen = dashboard().view(path: "areas-kitchen")
        #expect(kitchen?.title == "Kitchen")
        #expect(kitchen?.icon == "mdi:countertop")
    }

    @Test func aStartingServerGetsItsOwnViewInsteadOfAnEmptyHome() {
        let starting = HomeRegistry(areas: HomeDashboardSampleHome.areas, serverState: .starting)
        let dashboard = HomeDashboardStrategy.generate(registry: starting)
        #expect(dashboard.views.count == 1)
        guard case let .panel(cards) = dashboard.views[0].content, case let .emptyState(card) = cards[0] else {
            Issue.record("A starting server should show a single empty-state card")
            return
        }
        #expect(card.title == HomeDashboardStrings.preview.startingTitle)
    }

    // MARK: - The overview

    @Test func groupsAreasUnderTheirFloorAndNamesTheFloorWhenThereIsMoreThanOne() {
        let sections = dashboard().overview?.content.sections ?? []
        let ground = sections.first { $0.id == "floor:ground_floor" }
        #expect(headings(of: ground) == ["Ground floor"])
        #expect(areaIds(of: ground) == ["living_room", "kitchen"])

        let first = sections.first { $0.id == "floor:first_floor" }
        #expect(headings(of: first) == ["First floor"])
        #expect(areaIds(of: first) == ["bedroom", "bathroom"])
    }

    @Test func callsTheOnlyFloorAreasRatherThanNamingIt() {
        let oneFloor = HomeRegistry(
            areas: [HomeArea(id: "kitchen", name: "Kitchen", floorId: "ground_floor")],
            floors: [HomeFloor(id: "ground_floor", name: "Ground floor", level: 0)]
        )
        let sections = HomeDashboardStrategy.generate(registry: oneFloor).overview?.content.sections ?? []
        #expect(headings(of: sections.first) == ["Areas"])
    }

    @Test func putsAreasWithNoFloorInTheirOwnSection() {
        let sections = dashboard().overview?.content.sections ?? []
        let loose = sections.first { $0.id == "areas" }
        #expect(headings(of: loose) == ["Other areas"])
        #expect(areaIds(of: loose) == ["garage"])
    }

    @Test func offersTheDevicesThatAreInNoRoom() {
        let loose = dashboard().overview?.content.sections.first { $0.id == "areas" }
        let tiles = loose?.cards.compactMap { card -> HomeTileCardConfig? in
            guard case let .tile(tile) = card else { return nil }
            return tile
        }
        #expect(tiles?.count == 1)
        #expect(tiles?.first?.tapAction == .navigate("other-devices"))
        #expect(tiles?.first?.columns == 4)
    }

    @Test func dropsTheDevicesTileWhenEveryEntityHasARoom() {
        let tidy = HomeRegistry(
            areas: [HomeArea(id: "kitchen", name: "Kitchen")],
            devices: [HomeDevice(id: "lamp", name: "Lamp", areaId: "kitchen")],
            entities: [HomeEntityRegistration(id: "light.kitchen", deviceId: "lamp")],
            states: [HomeEntityState(id: "light.kitchen", state: "on")]
        )
        let loose = HomeDashboardStrategy.generate(registry: tidy).overview?.content.sections.first { $0.id == "areas" }
        #expect(loose?.cards.allSatisfy { if case .tile = $0 { false } else { true } } == true)
    }

    @Test func pinsTheFavouritesTheUserChose() {
        let favorites = dashboard().overview?.content.sections.first { $0.id == "favorites" }
        #expect(headings(of: favorites) == ["Favorites"])
        #expect(entityIds(of: favorites) == ["light.kitchen_counter", "climate.living_room"])
    }

    @Test func dropsAFavouriteTheServerNoLongerHas() {
        let config = HomeDashboardStrategyConfig(favoriteEntityIds: ["light.kitchen_counter", "light.gone"])
        let dashboard = HomeDashboardStrategy.generate(config: config, registry: registry)
        let favorites = dashboard.overview?.content.sections.first { $0.id == "favorites" }
        #expect(entityIds(of: favorites) == ["light.kitchen_counter"])
    }

    @Test func greetsTheUserUnlessTheyTurnedItOff() {
        #expect(dashboard().overview?.header?.userName == "Bruno")
        let quiet = HomeDashboardStrategyConfig(hidesWelcomeMessage: true)
        #expect(HomeDashboardStrategy.generate(config: quiet, registry: registry).overview?.header == nil)
    }

    @Test func showsTheEmptyHomeWhenThereAreNoAreas() {
        let dashboard = HomeDashboardStrategy.generate(registry: HomeDashboardSampleHome.emptyRegistry)
        guard case let .panel(cards) = dashboard.overview?.content, case let .emptyState(card) = cards[0] else {
            Issue.record("A home with no areas should be a single empty-state card")
            return
        }
        #expect(card.title == "No devices here yet")
        // The admin is offered a way out of it; anybody else is only told.
        #expect(card.buttons.map(\.id) == ["add-device", "edit-areas"])
    }

    // MARK: - Summaries

    @Test func offersASummaryPerCornerOfTheHomeInTheFrontendsOrder() {
        let summaries = dashboard().overview?.content.sections.first { $0.id == "summaries" }
        #expect(summaryKinds(of: summaries) == [.light, .climate, .security, .mediaPlayers, .maintenance, .energy])
        // Weather is a plain tile rather than a summary, and comes after the rest.
        #expect(entityIds(of: summaries) == ["weather.home"])
    }

    @Test func countsOnlyTheEntitiesASummaryIsAbout() {
        let summaries = dashboard().overview?.content.sections.first { $0.id == "summaries" }
        let lights = summaryCards(of: summaries).first { $0.summary == .light }
        #expect(lights?.entityIds == [
            "light.living_room_ceiling",
            "light.kitchen_counter",
            "light.kitchen_ceiling",
            "light.bedroom_bedside",
            "light.bathroom_ceiling",
        ])
    }

    @Test func leavesOutASummaryWhosePanelTheServerDoesNotHave() {
        let noLightPanel = HomeRegistry(
            areas: HomeDashboardSampleHome.areas,
            floors: HomeDashboardSampleHome.floors,
            devices: HomeDashboardSampleHome.devices,
            entities: HomeDashboardSampleHome.entities,
            states: HomeDashboardSampleHome.states,
            panels: ["climate"]
        )
        let summaries = HomeDashboardStrategy.generate(registry: noLightPanel)
            .overview?.content.sections.first { $0.id == "summaries" }
        #expect(!summaryKinds(of: summaries).contains(.light))
    }

    @Test func offersTheSameSummariesToTheSidebarAtFullWidth() {
        let sections = dashboard().overview?.content.sections ?? []
        let flow = sections.first { $0.id == "summaries" }
        let sidebar = sections.first { $0.id == "summaries-sidebar" }
        #expect(flow?.visibility == .smallScreen)
        #expect(sidebar?.visibility == .largeScreen)
        #expect(summaryCards(of: flow).allSatisfy { $0.columns == 6 })
        #expect(summaryCards(of: sidebar).allSatisfy { $0.columns == 12 })
    }

    // MARK: - A room

    @Test func groupsARoomsEntitiesByWhatTheyAreFor() {
        let livingRoom = dashboard().view(path: "areas-living_room")
        #expect(livingRoom?.content.sections.map(\.id) == [
            "light",
            "climate",
            "media_players",
            "scenes",
            "devices-separator",
            "device:thermostat",
            "device:air_quality",
            "automations",
        ])
    }

    @Test func stripsTheRoomsNameOffItsEntities() {
        let livingRoom = dashboard().view(path: "areas-living_room")
        let lights = livingRoom?.content.sections.first { $0.id == "light" }
        let tile = lights?.cards.compactMap { card -> HomeTileCardConfig? in
            guard case let .tile(tile) = card else { return nil }
            return tile
        }.first
        #expect(tile?.entityId == "light.living_room_ceiling")
        #expect(tile?.name == "Ceiling")
    }

    @Test func offersTheControlEachEntitySupports() {
        let livingRoom = dashboard().view(path: "areas-living_room")
        let light = tile(in: livingRoom, entityId: "light.living_room_ceiling")
        #expect(light?.feature == .lightBrightness)
        let garage = dashboard().view(path: "areas-garage")
        #expect(tile(in: garage, entityId: "cover.garage_door")?.feature == .coverOpenClose)
        #expect(tile(in: garage, entityId: "lock.front_door")?.feature == .lockCommands)
    }

    @Test func putsTheRoomsTemperatureAndHumidityOverIt() {
        let livingRoom = dashboard().view(path: "areas-living_room")
        #expect(livingRoom?.badges.map(\.entityId) == [
            "sensor.living_room_temperature",
            "sensor.living_room_humidity",
        ])
        #expect(livingRoom?.badges.map(\.color) == ["red", "indigo"])
    }

    @Test func offersToTurnTheRoomsLightsOnAndOff() {
        let livingRoom = dashboard().view(path: "areas-living_room")
        let lights = livingRoom?.content.sections.first { $0.id == "light" }
        guard case let .heading(heading)? = lights?.cards.first else {
            Issue.record("A room's lights should start with a heading")
            return
        }
        #expect(heading.badges.count == 2)
        guard case let .button(off) = heading.badges[0], case let .button(on) = heading.badges[1] else {
            Issue.record("Both badges should be buttons")
            return
        }
        // The pair is one control: exactly one of them is ever visible.
        #expect(off.visibility == .noneOn(["light.living_room_ceiling"]))
        #expect(on.visibility == .anyOn(["light.living_room_ceiling"]))
        #expect(off.tapAction == .performAction(HomeServiceCall(service: "light.turn_on", areaId: "living_room")))
        #expect(on.tapAction == .performAction(HomeServiceCall(service: "light.turn_off", areaId: "living_room")))
    }

    @Test func showsACameraAsItsPictureRatherThanAsATile() {
        let garage = dashboard().view(path: "areas-garage")
        let security = garage?.content.sections.first { $0.id == "security" }
        let pictures = security?.cards.compactMap { card -> HomePictureEntityCardConfig? in
            guard case let .pictureEntity(picture) = card else { return nil }
            return picture
        }
        #expect(pictures?.map(\.entityId) == ["camera.doorbell"])
    }

    @Test func groupsWhatIsLeftByTheDeviceItBelongsTo() {
        let kitchen = dashboard().view(path: "areas-kitchen")
        let dishwasher = kitchen?.content.sections.first { $0.id == "device:dishwasher" }
        #expect(headings(of: dishwasher) == ["Dishwasher"])
        // The diagnostic entity is not a control and stays off the room's screen.
        #expect(entityIds(of: dishwasher) == ["switch.kitchen_dishwasher"])
    }

    @Test func showsADevicesBatteryBesideItsNameRatherThanAsACard() {
        let bedroom = dashboard().view(path: "areas-bedroom")
        let sensor = bedroom?.content.sections.first { $0.id == "device:window_sensor" }
        guard case let .heading(heading)? = sensor?.cards.first else {
            Issue.record("A device's section should start with a heading")
            return
        }
        #expect(heading.badges.map(\.id) == ["entity:sensor.bedroom_window_battery"])
        #expect(!entityIds(of: sensor).contains("sensor.bedroom_window_battery"))
    }

    @Test func prefersTheNameTheUserGaveADevice() {
        let livingRoom = dashboard().view(path: "areas-living_room")
        // The integration called it "Thermostat"; the user called it something else.
        #expect(
            headings(of: livingRoom?.content.sections.first { $0.id == "device:thermostat" }) ==
                ["Living room thermostat"]
        )
        #expect(
            headings(of: livingRoom?.content.sections.first { $0.id == "device:air_quality" }) ==
                ["Air quality sensor"]
        )
    }

    @Test func leavesOutTheEnergySummaryUntilTheEnergyDashboardHasASource() {
        let unconfigured = HomeRegistry(
            areas: HomeDashboardSampleHome.areas,
            floors: HomeDashboardSampleHome.floors,
            devices: HomeDashboardSampleHome.devices,
            entities: HomeDashboardSampleHome.entities,
            states: HomeDashboardSampleHome.states,
            panels: ["energy"],
            hasEnergyData: false
        )
        let summaries = HomeDashboardStrategy.generate(registry: unconfigured)
            .overview?.content.sections.first { $0.id == "summaries" }
        #expect(!summaryKinds(of: summaries).contains(.energy))
    }

    @Test func showsTheEmptyRoomWhenThereIsNothingInIt() {
        let empty = HomeRegistry(areas: [HomeArea(id: "attic", name: "Attic", icon: "mdi:home-roof")], isAdmin: true)
        let attic = HomeDashboardStrategy.generate(registry: empty).view(path: "areas-attic")
        guard case let .panel(cards) = attic?.content, case let .emptyState(card) = cards[0] else {
            Issue.record("An empty room should be a single empty-state card")
            return
        }
        #expect(card.title == "This is a blank canvas")
        #expect(card.icon == "mdi:home-roof")
    }

    // MARK: - Helpers

    private func headings(of section: HomeDashboardSectionConfig?) -> [String] {
        (section?.cards ?? []).compactMap { card in
            guard case let .heading(heading) = card else { return nil }
            return heading.heading
        }
    }

    private func areaIds(of section: HomeDashboardSectionConfig?) -> [String] {
        (section?.cards ?? []).compactMap { card in
            guard case let .area(area) = card else { return nil }
            return area.areaId
        }
    }

    private func entityIds(of section: HomeDashboardSectionConfig?) -> [String] {
        (section?.cards ?? []).compactMap(\.entityId)
    }

    private func summaryCards(of section: HomeDashboardSectionConfig?) -> [HomeSummaryCardConfig] {
        (section?.cards ?? []).compactMap { card in
            guard case let .summary(summary) = card else { return nil }
            return summary
        }
    }

    private func summaryKinds(of section: HomeDashboardSectionConfig?) -> [HomeSummaryKind] {
        summaryCards(of: section).map(\.summary)
    }

    private func tile(in view: HomeDashboardViewConfig?, entityId: String) -> HomeTileCardConfig? {
        (view?.content.sections ?? []).flatMap(\.cards).compactMap { card -> HomeTileCardConfig? in
            guard case let .tile(tile) = card, tile.entityId == entityId else { return nil }
            return tile
        }.first
    }
}
