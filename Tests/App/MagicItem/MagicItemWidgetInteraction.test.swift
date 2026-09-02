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

    /// The frontend's tile card gives a read-only entity's icon no action at all; here it opens the
    /// entity like the rest of the tile does, so the tile isn't split and the icon is drawn plain.
    @Test func readOnlyEntityIsNotSplitAndKeepsItsIconPlain() {
        let item = MagicItem(id: "sensor.temperature", serverId: "1", type: .entity)

        #expect(Self.opensMoreInfo(item.widgetInteractionType, entityId: "sensor.temperature"))
        #expect(item.widgetInteractionType == item.widgetTapInteractionType)
        #expect(!item.controlsEntityFromWidget)
    }

    /// A lock is not one of the frontend's toggle-by-default domains, so its icon opens it until
    /// told otherwise — but it can be told to toggle, which locks or unlocks by its state.
    @Test func lockOpensMoreInfoByDefaultButCanToggle() {
        var item = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)

        #expect(Self.opensMoreInfo(item.widgetInteractionType, entityId: "lock.front_door"))
        #expect(!item.controlsEntityFromWidget)

        item.action = .toggle
        #expect(item.widgetInteractionType == .appIntent(.toggle(
            entityId: "lock.front_door",
            domain: "lock",
            serverId: "1"
        )))
        #expect(item.controlsEntityFromWidget)
    }

    /// A script isn't in the frontend's toggle-by-default set either: its tile opens the script,
    /// and only an explicit "toggle" runs it from the icon.
    @Test func scriptOpensMoreInfoUntilToldToToggle() {
        var item = MagicItem(id: "script.morning", serverId: "1", type: .script)

        #expect(Self.opensMoreInfo(item.widgetInteractionType, entityId: "script.morning"))
        #expect(!item.controlsEntityFromWidget)
        #expect(item.widgetInteractionType == item.widgetTapInteractionType)

        item.action = .toggle
        #expect(item.widgetInteractionType == .appIntent(.toggle(
            entityId: "script.morning",
            domain: "script",
            serverId: "1"
        )))
    }

    /// A scene is one of the domains whose icon runs by default, like a button.
    @Test func sceneAndButtonIconsActivateByDefault() {
        let scene = MagicItem(id: "scene.movie", serverId: "1", type: .scene)
        #expect(scene.widgetInteractionType == .appIntent(.toggle(
            entityId: "scene.movie",
            domain: "scene",
            serverId: "1"
        )))
        #expect(scene.controlsEntityFromWidget)

        let button = MagicItem(id: "button.doorbell", serverId: "1", type: .entity)
        #expect(button.widgetInteractionType == .appIntent(.toggle(
            entityId: "button.doorbell",
            domain: "button",
            serverId: "1"
        )))
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
    }

    /// "Nothing" was retired: an item saved with it still decodes, behaves as the default, and the
    /// picker neither offers nor shows it.
    @Test func retiredNothingBehavesAsTheDefault() throws {
        let stored = Data("""
        {"id":"light.kitchen","serverId":"1","type":"entity","action":{"nothing":{}},"tapAction":{"nothing":{}}}
        """.utf8)

        let item = try JSONDecoder().decode(MagicItem.self, from: stored)

        #expect(item.action == .nothing)
        #expect(item.action?.isRetired == true)
        #expect(item.widgetInteractionType == .appIntent(.toggle(
            entityId: "light.kitchen",
            domain: "light",
            serverId: "1"
        )))
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "light.kitchen"))
        #expect(!ItemAction.allCases.map(\.id).contains(ItemAction.nothing.id))
        #expect(!ItemAction.offered(for: item, selected: .default).map(\.id).contains(ItemAction.nothing.id))
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

    /// The frontend's "toggle" runs the entity's on or off service; a domain without such a pair —
    /// a sensor — has nothing to toggle, so the item keeps the behavior it would have had anyway.
    @Test func toggleActionTogglesTheDomainOrFallsBack() {
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
        sensor.tapAction = .toggle
        #expect(Self.opensMoreInfo(sensor.widgetTapInteractionType, entityId: "sensor.temperature"))
    }

    /// "Toggle" is offered to exactly the domains the frontend's `canToggleDomain` accepts: the ones
    /// with an on/off service pair, a lock included, and a button or scene whose single service
    /// stands in for both. A sensor has none, and neither does an entity of a domain the app
    /// doesn't know.
    @Test func toggleIsOfferedToTheDomainsTheFrontendToggles() {
        for entityId in [
            "light.kitchen", "switch.fan", "fan.bedroom", "cover.garage", "valve.water", "lock.front_door",
            "climate.living_room", "media_player.tv", "automation.night", "button.doorbell", "input_button.ring",
            "group.downstairs", "humidifier.bedroom", "input_boolean.guest", "camera.porch", "siren.alarm",
            "remote.tv", "water_heater.tank",
        ] {
            #expect(MagicItem(id: entityId, serverId: "1", type: .entity).canToggle, "\(entityId)")
        }
        #expect(MagicItem(id: "script.morning", serverId: "1", type: .script).canToggle)
        #expect(MagicItem(id: "scene.movie", serverId: "1", type: .scene).canToggle)

        for entityId in ["sensor.temperature", "binary_sensor.door", "vacuum.roomba", "weather.home", "custom.thing"] {
            #expect(!MagicItem(id: entityId, serverId: "1", type: .entity).canToggle, "\(entityId)")
        }
        #expect(!MagicItem(id: "pipeline-1", serverId: "1", type: .assistPipeline).canToggle)

        let sensor = MagicItem(id: "sensor.temperature", serverId: "1", type: .entity)
        let sensorOffered = ItemAction.offered(for: sensor, selected: .default).map(\.id)
        #expect(!sensorOffered.contains(ItemAction.toggle.id))
        #expect(!sensorOffered.contains(ItemAction.turnOn.id))
        #expect(!sensorOffered.contains(ItemAction.turnOff.id))
        #expect(sensorOffered == ItemAction.allCases.map(\.id).filter { id in
            ![ItemAction.toggle.id, ItemAction.turnOn.id, ItemAction.turnOff.id].contains(id)
        })

        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(ItemAction.offered(for: light, selected: .default).map(\.id) == ItemAction.allCases.map(\.id))

        // A choice already stored stays on screen even when it would no longer be offered.
        #expect(ItemAction.offered(for: sensor, selected: .toggle).map(\.id).contains(ItemAction.toggle.id))
    }

    /// The explicit on/off behaviors only make sense where "on" and "off" are different services:
    /// a button or a scene has one, and "toggle" already runs it.
    @Test func onOffBehaviorsAreOfferedWhereTheServicesDiffer() {
        let lock = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)
        #expect(lock.hasOnOffActions)
        let lockOffered = ItemAction.offered(for: lock, selected: .default).map(\.id)
        #expect(lockOffered.contains(ItemAction.turnOn.id))
        #expect(lockOffered.contains(ItemAction.turnOff.id))

        for item in [
            MagicItem(id: "button.doorbell", serverId: "1", type: .entity),
            MagicItem(id: "input_button.ring", serverId: "1", type: .entity),
            MagicItem(id: "scene.movie", serverId: "1", type: .scene),
        ] {
            #expect(!item.hasOnOffActions, "\(item.id)")
            let offered = ItemAction.offered(for: item, selected: .default).map(\.id)
            #expect(offered.contains(ItemAction.toggle.id), "\(item.id)")
            #expect(!offered.contains(ItemAction.turnOn.id), "\(item.id)")
        }
    }

    /// The on/off behaviors call the domain's own service outright, and are named after it: a lock
    /// unlocks and locks, a cover opens and closes, a group goes through `homeassistant`.
    @Test func onOffBehaviorsCallTheDomainsOwnServices() {
        var lock = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)
        lock.action = .turnOn
        #expect(lock.widgetInteractionType == .appIntent(.performAction(
            serverId: "1",
            actionId: "lock.unlock",
            payload: "{\"entity_id\": \"lock.front_door\"}"
        )))
        lock.action = .turnOff
        #expect(lock.widgetInteractionType == .appIntent(.performAction(
            serverId: "1",
            actionId: "lock.lock",
            payload: "{\"entity_id\": \"lock.front_door\"}"
        )))
        #expect(lock.controlsEntityFromWidget)
        #expect(ItemAction.turnOn.name(for: .lock) == "Unlock")
        #expect(ItemAction.turnOff.name(for: .lock) == "Lock")

        var cover = MagicItem(id: "cover.garage", serverId: "1", type: .entity)
        cover.tapAction = .turnOff
        #expect(cover.widgetTapInteractionType == .appIntent(.performAction(
            serverId: "1",
            actionId: "cover.close_cover",
            payload: "{\"entity_id\": \"cover.garage\"}"
        )))
        #expect(ItemAction.turnOn.name(for: .cover) == "Open")
        #expect(ItemAction.turnOff.name(for: .cover) == "Close")

        var group = MagicItem(id: "group.downstairs", serverId: "1", type: .entity)
        group.action = .turnOn
        #expect(group.widgetInteractionType == .appIntent(.performAction(
            serverId: "1",
            actionId: "homeassistant.turn_on",
            payload: "{\"entity_id\": \"group.downstairs\"}"
        )))
        #expect(ItemAction.turnOn.name(for: .light) == "Turn on")
        #expect(ItemAction.turnOff.name(for: .light) == "Turn off")

        // A button has no "off" to call, so the choice falls back to the icon's default.
        var button = MagicItem(id: "button.doorbell", serverId: "1", type: .entity)
        button.action = .turnOff
        #expect(button.widgetInteractionType == .appIntent(.toggle(
            entityId: "button.doorbell",
            domain: "button",
            serverId: "1"
        )))
    }

    /// "Default" on the customization screen names what it stands for, and that name is what the
    /// tile runs — the frontend tile card's defaults, with more-info where the card would do
    /// nothing: the icon toggles for the toggle domains and opens the entity otherwise, and the
    /// rest of the tile always opens the entity.
    @Test func defaultActionsNameWhatTheTileDoes() {
        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(light.defaultIconAction == .toggle)
        #expect(light.defaultTapAction == .moreInfoDialog)

        let scene = MagicItem(id: "scene.movie", serverId: "1", type: .scene)
        #expect(scene.defaultIconAction == .toggle)

        for item in [
            MagicItem(id: "script.morning", serverId: "1", type: .script),
            MagicItem(id: "sensor.temperature", serverId: "1", type: .entity),
            MagicItem(id: "lock.front_door", serverId: "1", type: .entity),
            MagicItem(id: "cover.garage", serverId: "1", type: .entity),
            MagicItem(id: "custom.thing", serverId: "1", type: .entity),
        ] {
            #expect(item.defaultIconAction == .moreInfoDialog, "\(item.id)")
            #expect(item.defaultTapAction == .moreInfoDialog, "\(item.id)")
        }

        // No entity behind a pipeline, so both halves of the tile start Assist.
        var pipeline = MagicItem(id: "pipeline-1", serverId: "1", type: .assistPipeline)
        pipeline.assistPipelineId = "pipeline-1"
        #expect(pipeline.defaultIconAction == .assist("1", "pipeline-1", true))
        #expect(pipeline.defaultTapAction == .assist("1", "pipeline-1", true))

        #expect(ItemAction.defaultName(resolvingTo: ItemAction.toggle.name) == "Default (Toggle)")
        #expect(ItemAction.defaultName(resolvingTo: ItemAction.moreInfoDialog.name) == "Default (More info)")
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
