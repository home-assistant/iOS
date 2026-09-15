@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// What the translated dashboard actually looks like. The engine's own tests say the right cards are
/// there; these say they read as a Home Assistant screen.
///
/// Drawn through the app's presenter rather than the design system's stand-in, so a reference image
/// shows the icons, colours and wording that ship.
@MainActor
struct HomeDashboardSnapshotTests {
    private var registry: HomeRegistry { HomeDashboardSampleHome.registry }

    private func dashboard(registry: HomeRegistry) -> HomeDashboardConfig {
        HomeDashboardStrategy.generate(
            config: HomeDashboardSampleHome.strategyConfig,
            registry: registry,
            strings: .app
        )
    }

    private func page(_ view: HomeDashboardViewConfig?, registry: HomeRegistry) -> AnyView {
        let context = HomeDashboardContext(
            registry: registry,
            strings: .app,
            presenter: .app(
                entities: HomeDashboardEntityFixtures.entities,
                iconsMap: nil,
                serverId: "fixture"
            )
        )
        return AnyView(
            HomeDashboardPage(config: view!, areaOrder: registry.areas.map(\.id))
                .environment(\.homeDashboard, context)
                .environmentObject(HomeAreaReorderCoordinator { _ in })
        )
    }

    @Test func overview() async throws {
        assertLightDarkSnapshots(
            of: page(dashboard(registry: registry).overview, registry: registry),
            named: "overview"
        )
    }

    @Test func areaWithEverythingInIt() async throws {
        let view = dashboard(registry: registry).view(path: "areas-living_room")
        assertLightDarkSnapshots(of: page(view, registry: registry), named: "area-living-room")
    }

    @Test func areaWithOneSection() async throws {
        let view = dashboard(registry: registry).view(path: "areas-garage")
        assertLightDarkSnapshots(of: page(view, registry: registry), named: "area-garage")
    }

    @Test func homeWithNoAreas() async throws {
        let empty = HomeDashboardSampleHome.emptyRegistry
        assertLightDarkSnapshots(of: page(dashboard(registry: empty).overview, registry: empty), named: "empty-home")
    }

    @Test func areaWithNothingInIt() async throws {
        let bare = HomeRegistry(areas: [HomeArea(id: "attic", name: "Attic", icon: "mdi:home-roof")], isAdmin: true)
        let view = HomeDashboardStrategy.generate(registry: bare, strings: .app).view(path: "areas-attic")
        assertLightDarkSnapshots(of: page(view, registry: bare), named: "empty-area")
    }

    /// The whole thing on an iPad, where the summaries move into a column of their own rather than
    /// sitting in the flow — the one difference the generated config carries twice and the renderer
    /// picks between.
    @Test func overviewOnAWideScreen() async throws {
        assertSnapshot(
            of: page(dashboard(registry: registry).overview, registry: registry),
            layout: .device(config: .iPadPro11(.landscape)),
            named: "overview-ipad"
        )
    }

    /// A room's lights while one of them is on: the heading's badge is the other one of the pair.
    @Test func areaWithItsLightsOn() async throws {
        let view = dashboard(registry: registry).view(path: "areas-kitchen")
        assertLightDarkSnapshots(of: page(view, registry: registry), named: "area-kitchen")
    }

    /// A room whose name wraps beside one whose name does not: both cards are the same size, both
    /// icons on one line, and each name centred in the space under its own icon.
    @Test func roomsWithLongAndShortNames() async throws {
        let registry = HomeRegistry(
            areas: [
                HomeArea(id: "hall", name: "Hall", icon: "mdi:coat-rack", floorId: "ground_floor"),
                HomeArea(
                    id: "guest_bathroom",
                    name: "Downstairs guest bathroom",
                    icon: "mdi:shower",
                    floorId: "ground_floor"
                ),
            ],
            floors: [HomeFloor(id: "ground_floor", name: "Ground floor", level: 0)]
        )
        let view = HomeDashboardStrategy.generate(registry: registry, strings: .app).overview
        assertLightDarkSnapshots(of: page(view, registry: registry), named: "long-room-names")
    }

    /// Every player in the house, grouped by the room it is in.
    @Test func mediaPlayers() async throws {
        let view = dashboard(registry: registry).view(path: "media-players")
        assertLightDarkSnapshots(of: page(view, registry: registry), named: "media-players")
    }

    /// And the devices that belong to no room at all.
    @Test func otherDevices() async throws {
        let view = dashboard(registry: registry).view(path: "other-devices")
        assertLightDarkSnapshots(of: page(view, registry: registry), named: "other-devices")
    }
}
