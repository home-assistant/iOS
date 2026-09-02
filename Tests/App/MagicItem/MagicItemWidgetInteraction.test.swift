@testable import Shared
import Testing

/// A widget tile is two controls, the way the frontend's tile card is: the icon acts on the entity
/// and the rest of the tile opens it. These cover which of the two a given item resolves to, and
/// when the two collapse back into one.
struct MagicItemWidgetInteractionTests {
    @Test func controllableEntityIconTogglesAndTapOpensMoreInfo() {
        let item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)

        #expect(item.widgetInteractionType == .appIntent(.toggle(
            entityId: "light.kitchen",
            domain: "light",
            serverId: "1"
        )))
        #expect(item.controlsEntityFromWidget)
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "light.kitchen"))
        // The two halves differ, so the tile is split.
        #expect(item.widgetInteractionType != item.widgetTapInteractionType)
    }

    @Test func readOnlyEntityIsNotSplitAndKeepsItsIconPlain() {
        let item = MagicItem(id: "sensor.temperature", serverId: "1", type: .entity)

        #expect(Self.opensMoreInfo(item.widgetInteractionType, entityId: "sensor.temperature"))
        #expect(item.widgetInteractionType == item.widgetTapInteractionType)
        #expect(!item.controlsEntityFromWidget)
    }

    /// A lock has no single main action, so both halves open it — which is exactly a tile that isn't
    /// split, and an icon drawn without its background.
    @Test func lockOpensMoreInfoFromBothHalves() {
        let item = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)

        #expect(item.widgetInteractionType == item.widgetTapInteractionType)
        #expect(!item.controlsEntityFromWidget)
    }

    @Test func scriptIsControllableAndOpensMoreInfoOnTap() {
        let item = MagicItem(id: "script.morning", serverId: "1", type: .script)

        #expect(item.widgetInteractionType == .appIntent(.activate(
            entityId: "script.morning",
            domain: "script",
            serverId: "1"
        )))
        #expect(item.controlsEntityFromWidget)
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "script.morning"))
    }

    @Test func chosenTapBehaviorWinsOverTheDefaultMoreInfoDialog() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .navigate("/lovelace/0")

        guard case let .widgetURL(url) = item.widgetTapInteractionType else {
            Issue.record("Expected a deep link, got \(item.widgetTapInteractionType)")
            return
        }
        #expect(url.absoluteString.contains("lovelace/0"))
        // The icon keeps controlling the entity.
        #expect(item.controlsEntityFromWidget)
    }

    /// An icon that only opens the app is not a control, so it loses its background — whichever way
    /// it was told to open it.
    @Test func iconThatOnlyOpensTheAppIsNotAControl() {
        var navigating = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        navigating.action = .navigate("/lovelace/0")
        #expect(!navigating.controlsEntityFromWidget)

        var moreInfo = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        moreInfo.action = .moreInfoDialog
        #expect(!moreInfo.controlsEntityFromWidget)

        var nothing = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        nothing.action = .nothing
        #expect(!nothing.controlsEntityFromWidget)
    }

    /// An Assist pipeline has no entity behind it, so there is no dialog for the rest of the tile to
    /// open and the whole tile keeps starting Assist.
    @Test func assistPipelineKeepsOneBehaviorForTheWholeTile() {
        let item = MagicItem(id: "pipeline-1", serverId: "1", type: .assistPipeline)

        #expect(!item.hasMoreInfoDialog)
        #expect(item.widgetInteractionType == item.widgetTapInteractionType)
    }

    /// Items saved before the tile was split have no `tapAction` at all; they must read back as the
    /// default, not as a tile that does nothing.
    @Test func itemStoredBeforeTapBehaviorExistedFallsBackToTheDefault() throws {
        let stored = Data("""
        {"id":"light.kitchen","serverId":"1","type":"entity"}
        """.utf8)

        let item = try JSONDecoder().decode(MagicItem.self, from: stored)

        #expect(item.tapAction == nil)
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "light.kitchen"))
        #expect(item.widgetInteractionType == .appIntent(.toggle(
            entityId: "light.kitchen",
            domain: "light",
            serverId: "1"
        )))
    }

    /// The frontend's "toggle" runs the entity's domain action; a domain without one — a sensor —
    /// has nothing to toggle, so the item keeps the behavior it would have had anyway.
    @Test func toggleActionRunsTheDomainActionOrFallsBack() {
        var light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        light.tapAction = .toggle
        #expect(light.widgetTapInteractionType == .appIntent(.toggle(
            entityId: "light.kitchen",
            domain: "light",
            serverId: "1"
        )))

        var sensor = MagicItem(id: "sensor.temperature", serverId: "1", type: .entity)
        sensor.action = .toggle
        #expect(Self.opensMoreInfo(sensor.widgetInteractionType, entityId: "sensor.temperature"))
        #expect(!sensor.controlsEntityFromWidget)
    }

    /// "Toggle" is only worth offering to an item whose domain the app can run in one tap — the
    /// frontend's action editor drops it the same way for an entity that can't be toggled. A lock is
    /// state-aware and a sensor read-only, so neither gets it; a script or scene runs, so both do.
    @Test func toggleIsOnlyOfferedToItemsTheAppCanToggle() {
        #expect(MagicItem(id: "light.kitchen", serverId: "1", type: .entity).canToggle)
        #expect(MagicItem(id: "switch.fan", serverId: "1", type: .entity).canToggle)
        #expect(MagicItem(id: "button.doorbell", serverId: "1", type: .entity).canToggle)
        #expect(MagicItem(id: "automation.night", serverId: "1", type: .entity).canToggle)
        #expect(MagicItem(id: "script.morning", serverId: "1", type: .script).canToggle)
        #expect(MagicItem(id: "scene.movie", serverId: "1", type: .scene).canToggle)

        #expect(!MagicItem(id: "sensor.temperature", serverId: "1", type: .entity).canToggle)
        #expect(!MagicItem(id: "lock.front_door", serverId: "1", type: .entity).canToggle)
        #expect(!MagicItem(id: "climate.living_room", serverId: "1", type: .entity).canToggle)
        #expect(!MagicItem(id: "media_player.tv", serverId: "1", type: .entity).canToggle)
        #expect(!MagicItem(id: "custom.thing", serverId: "1", type: .entity).canToggle)
        #expect(!MagicItem(id: "pipeline-1", serverId: "1", type: .assistPipeline).canToggle)

        let offered = ItemAction.offered(canToggle: false, selected: .default).map(\.id)
        #expect(!offered.contains(ItemAction.toggle.id))
        #expect(offered == ItemAction.allCases.map(\.id).filter { $0 != ItemAction.toggle.id })
        #expect(ItemAction.offered(canToggle: true, selected: .default).map(\.id) == ItemAction.allCases.map(\.id))
        // A choice already stored stays on screen even when it would no longer be offered.
        #expect(ItemAction.offered(canToggle: false, selected: .toggle).map(\.id).contains(ItemAction.toggle.id))
    }

    /// "Default" on the customization screen names what it stands for, and that name is the behavior
    /// the tile actually runs: the icon of a controllable entity toggles, everything else opens the
    /// entity, and the rest of the tile always opens it.
    @Test func defaultActionsNameWhatTheTileDoes() {
        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(light.defaultIconAction == .toggle)
        #expect(light.defaultTapAction == .moreInfoDialog)

        let script = MagicItem(id: "script.morning", serverId: "1", type: .script)
        #expect(script.defaultIconAction == .toggle)
        #expect(script.defaultTapAction == .moreInfoDialog)

        let sensor = MagicItem(id: "sensor.temperature", serverId: "1", type: .entity)
        #expect(sensor.defaultIconAction == .moreInfoDialog)
        #expect(sensor.defaultTapAction == .moreInfoDialog)

        let lock = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)
        #expect(lock.defaultIconAction == .moreInfoDialog)

        let unknownDomain = MagicItem(id: "custom.thing", serverId: "1", type: .entity)
        #expect(unknownDomain.defaultIconAction == .moreInfoDialog)

        // No entity behind a pipeline, so both halves of the tile start Assist.
        var pipeline = MagicItem(id: "pipeline-1", serverId: "1", type: .assistPipeline)
        pipeline.assistPipelineId = "pipeline-1"
        #expect(pipeline.defaultIconAction == .assist("1", "pipeline-1", true))
        #expect(pipeline.defaultTapAction == .assist("1", "pipeline-1", true))

        #expect(ItemAction.defaultName(resolvingTo: .toggle) == "Default (Toggle)")
        #expect(ItemAction.defaultName(resolvingTo: .moreInfoDialog) == "Default (More info)")
    }

    /// A `url` action opens exactly what was typed, and an address typed without a scheme still
    /// reaches the web rather than leaving the tile dead.
    @Test func urlActionOpensTheTypedAddress() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .url("https://www.home-assistant.io/docs")
        #expect(item.widgetTapInteractionType == .widgetURL(URL(string: "https://www.home-assistant.io/docs")!))

        item.tapAction = .url("www.home-assistant.io/docs")
        #expect(item.widgetTapInteractionType == .widgetURL(URL(string: "https://www.home-assistant.io/docs")!))

        // Nothing typed yet: the tile refreshes instead of pointing nowhere.
        item.tapAction = .url("")
        #expect(item.widgetTapInteractionType == .appIntent(.refresh))
    }

    /// "Perform action" calls the chosen `domain.service` where the tile stands, so its icon keeps
    /// its control background.
    @Test func performActionCallsTheChosenAction() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.action = .performAction("1", "light.turn_on", "{\"brightness\": 120}")

        #expect(item.widgetInteractionType == .appIntent(.performAction(
            serverId: "1",
            actionId: "light.turn_on",
            payload: "{\"brightness\": 120}"
        )))
        #expect(item.controlsEntityFromWidget)
    }

    private static func opensMoreInfo(_ interactionType: WidgetInteractionType, entityId: String) -> Bool {
        guard case let .widgetURL(url) = interactionType else { return false }
        return url.absoluteString.contains("\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=\(entityId)")
    }
}
