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

    /// A lock is actionable, so its icon locks or unlocks it by state. It is the one domain that
    /// always confirms first, whether or not the item asked for confirmation.
    @Test func lockTogglesFromItsIconAndAlwaysConfirms() {
        let item = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)

        #expect(item.widgetInteractionType == .appIntent(.toggle(
            entityId: "lock.front_door",
            domain: "lock",
            serverId: "1"
        )))
        #expect(item.controlsEntityFromWidget)
        #expect(item.requiresConfirmation)
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "lock.front_door"))

        var light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(!light.requiresConfirmation)
        light.customization = .init(requiresConfirmation: true)
        #expect(light.requiresConfirmation)
    }

    /// A widget with nowhere to hold a pending confirmation can't run a lock at all, so its tile
    /// opens the entity instead. Every other domain keeps its default there.
    @Test func aWidgetThatCannotConfirmDoesNotRunALock() {
        let lock = MagicItem.entityTile(entityId: "lock.front_door", serverId: "1", canConfirm: false)
        #expect(lock.action == .moreInfoDialog)
        #expect(Self.opensMoreInfo(lock.widgetInteractionType, entityId: "lock.front_door"))
        #expect(!lock.controlsEntityFromWidget)

        let confirmable = MagicItem.entityTile(entityId: "lock.front_door", serverId: "1", canConfirm: true)
        #expect(confirmable.action == .default)
        #expect(confirmable.controlsEntityFromWidget)

        let light = MagicItem.entityTile(entityId: "light.kitchen", serverId: "1", canConfirm: false)
        #expect(light.action == .default)
        #expect(light.controlsEntityFromWidget)
    }

    /// A script's state says nothing about it, so its icon runs it rather than toggling it — the
    /// same "Run" the customization screen offers.
    @Test func scriptRunsFromItsIconByDefault() {
        let item = MagicItem(id: "script.morning", serverId: "1", type: .script)

        #expect(item.widgetInteractionType == .appIntent(.activate(
            entityId: "script.morning",
            domain: "script",
            serverId: "1"
        )))
        #expect(item.controlsEntityFromWidget)
        #expect(!item.requiresConfirmation)
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "script.morning"))
    }

    /// A scene activates and a button presses, both through the domain's main action.
    @Test func sceneAndButtonIconsActivateByDefault() {
        let scene = MagicItem(id: "scene.movie", serverId: "1", type: .scene)
        #expect(scene.widgetInteractionType == .appIntent(.activate(
            entityId: "scene.movie",
            domain: "scene",
            serverId: "1"
        )))
        #expect(scene.controlsEntityFromWidget)

        let button = MagicItem(id: "button.doorbell", serverId: "1", type: .entity)
        #expect(button.widgetInteractionType == .appIntent(.activate(
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

    /// "Nothing" was retired: an item saved with it still decodes and opens the entity instead —
    /// never its toggle, which an icon told to do nothing must not start running — and the picker
    /// neither offers nor shows it.
    @Test func retiredNothingOpensMoreInfo() throws {
        let stored = Data("""
        {"id":"light.kitchen","serverId":"1","type":"entity","action":{"nothing":{}},"tapAction":{"nothing":{}}}
        """.utf8)

        let item = try JSONDecoder().decode(MagicItem.self, from: stored)

        #expect(item.action == .nothing)
        #expect(item.action?.isRetired == true)
        #expect(Self.opensMoreInfo(item.widgetInteractionType, entityId: "light.kitchen"))
        #expect(!item.controlsEntityFromWidget)
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
        let domainSpecific = [ItemAction.toggle, .mainAction, .turnOn, .turnOff].map(\.id)
        #expect(sensorOffered == ItemAction.allCases.map(\.id).filter { !domainSpecific.contains($0) })

        // A light toggles and turns on and off; its main action is the toggle, so no extra entry.
        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(ItemAction.offered(for: light, selected: .default).map(\.id) == ItemAction.allCases.map(\.id).filter {
            $0 != ItemAction.mainAction.id
        })

        // A choice already stored stays on screen even when it would no longer be offered.
        #expect(ItemAction.offered(for: sensor, selected: .toggle).map(\.id).contains(ItemAction.toggle.id))
    }

    /// A cover, climate, camera, media player, or siren only toggles when its `supported_features`
    /// say it can turn on and off — the frontend's `canToggleState`. Until the features are read
    /// the domain decides, the way the frontend does without a state object.
    @Test func supportedFeaturesNarrowToggleTheWayTheFrontendDoes() {
        let cover = MagicItem(id: "cover.garage", serverId: "1", type: .entity)
        let openAndClose = CoverCapabilities.Feature.open.rawValue | CoverCapabilities.Feature.close.rawValue
        #expect(cover.canToggle(supportedFeatures: nil))
        #expect(cover.canToggle(supportedFeatures: openAndClose | CoverCapabilities.Feature.stop.rawValue))
        #expect(!cover.canToggle(supportedFeatures: CoverCapabilities.Feature.setPosition.rawValue))
        #expect(!cover.hasOnOffActions(supportedFeatures: CoverCapabilities.Feature.open.rawValue))

        let offered = ItemAction.offered(for: cover, supportedFeatures: 0, selected: .default).map(\.id)
        #expect(!offered.contains(ItemAction.toggle.id))
        #expect(!offered.contains(ItemAction.turnOn.id))
        let offeredWithFeatures = ItemAction.offered(for: cover, supportedFeatures: openAndClose, selected: .default)
        #expect(offeredWithFeatures.map(\.id).contains(ItemAction.toggle.id))

        let climate = MagicItem(id: "climate.living_room", serverId: "1", type: .entity)
        #expect(climate.canToggle(supportedFeatures: ClimateEntityFeature([.turnOn, .turnOff]).rawValue))
        #expect(!climate.canToggle(supportedFeatures: ClimateEntityFeature.targetTemperature.rawValue))

        // A light needs no feature to toggle, whatever it reports.
        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(light.canToggle(supportedFeatures: 0))
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

    /// A domain whose main action isn't a toggle gets that action as an entry of its own, named in
    /// its words: "Press" for a button, "Activate" for a scene, "Run" for a script, "Trigger" for an
    /// automation. A light's main action is the toggle, which "Toggle" already names, and a sensor
    /// has none.
    @Test func mainActionIsOfferedWhereToggleDoesNotNameIt() {
        let expected: [(item: MagicItem, name: String)] = [
            (MagicItem(id: "button.doorbell", serverId: "1", type: .entity), "Press"),
            (MagicItem(id: "input_button.ring", serverId: "1", type: .entity), "Press"),
            (MagicItem(id: "scene.movie", serverId: "1", type: .scene), "Activate"),
            (MagicItem(id: "script.morning", serverId: "1", type: .script), "Run"),
            (MagicItem(id: "automation.night", serverId: "1", type: .entity), "Trigger"),
        ]
        for (item, name) in expected {
            #expect(item.hasExplicitMainAction, "\(item.id)")
            let offered = ItemAction.offered(for: item, selected: .default).map(\.id)
            #expect(offered.contains(ItemAction.mainAction.id), "\(item.id)")
            #expect(ItemAction.mainAction.name(for: item.domain) == name, "\(item.id)")

            var chosen = item
            chosen.action = .mainAction
            #expect(chosen.widgetInteractionType == .appIntent(.activate(
                entityId: item.id,
                domain: item.domain!.rawValue,
                serverId: "1"
            )), "\(item.id)")
            #expect(chosen.controlsEntityFromWidget, "\(item.id)")
        }

        for item in [
            MagicItem(id: "light.kitchen", serverId: "1", type: .entity),
            MagicItem(id: "cover.garage", serverId: "1", type: .entity),
            MagicItem(id: "lock.front_door", serverId: "1", type: .entity),
            MagicItem(id: "sensor.temperature", serverId: "1", type: .entity),
        ] {
            #expect(!item.hasExplicitMainAction, "\(item.id)")
            let offered = ItemAction.offered(for: item, selected: .default).map(\.id)
            #expect(!offered.contains(ItemAction.mainAction.id), "\(item.id)")
        }

        // A light has no main action beyond its toggle, so the choice falls back to the icon's default.
        var light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        light.action = .mainAction
        #expect(light.widgetInteractionType == .appIntent(.toggle(
            entityId: "light.kitchen",
            domain: "light",
            serverId: "1"
        )))
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
    /// tile runs: the icon runs the domain's own action, and the rest of the tile opens the entity.
    @Test func defaultActionsNameWhatTheTileDoes() {
        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(light.defaultIconAction == .toggle)
        #expect(light.defaultTapAction == .moreInfoDialog)

        for item in [
            MagicItem(id: "lock.front_door", serverId: "1", type: .entity),
            MagicItem(id: "cover.garage", serverId: "1", type: .entity),
            MagicItem(id: "group.downstairs", serverId: "1", type: .entity),
            MagicItem(id: "valve.water", serverId: "1", type: .entity),
        ] {
            #expect(item.defaultIconAction == .toggle, "\(item.id)")
            #expect(item.defaultTapAction == .moreInfoDialog, "\(item.id)")
        }

        for item in [
            MagicItem(id: "scene.movie", serverId: "1", type: .scene),
            MagicItem(id: "script.morning", serverId: "1", type: .script),
            MagicItem(id: "button.doorbell", serverId: "1", type: .entity),
            MagicItem(id: "automation.night", serverId: "1", type: .entity),
        ] {
            #expect(item.defaultIconAction == .mainAction, "\(item.id)")
            #expect(item.defaultTapAction == .moreInfoDialog, "\(item.id)")
        }

        for item in [
            MagicItem(id: "sensor.temperature", serverId: "1", type: .entity),
            MagicItem(id: "media_player.tv", serverId: "1", type: .entity),
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
        #expect(ItemAction.defaultName(resolvingTo: ItemAction.mainAction.name(for: .script)) == "Default (Run)")
        #expect(
            ItemAction.defaultName(resolvingTo: ItemAction.mainAction.name(for: .automation)) ==
                "Default (Trigger)"
        )
    }

    /// Confirmation, when an item requires it, applies to whichever half is tapped — except a tap
    /// that only opens the entity, which is the one interaction that changes nothing. This is the
    /// test the tile runs before asking.
    @Test func onlyOpeningTheEntityIsExemptFromConfirmation() {
        let sensor = MagicItem(id: "sensor.temperature", serverId: "1", type: .entity)
        #expect(sensor.widgetInteractionType.opensEntityInApp)
        #expect(sensor.widgetTapInteractionType.opensEntityInApp)

        var item = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)
        #expect(item.widgetTapInteractionType.opensEntityInApp)
        item.action = .toggle
        #expect(!item.widgetInteractionType.opensEntityInApp)
        item.tapAction = .turnOff
        #expect(!item.widgetTapInteractionType.opensEntityInApp)
        item.tapAction = .navigate("/lovelace/0")
        #expect(!item.widgetTapInteractionType.opensEntityInApp)
        item.tapAction = .url("https://www.home-assistant.io")
        #expect(!item.widgetTapInteractionType.opensEntityInApp)
        // An address on the web is never an in-app destination, however it is shaped: only the
        // app's own deep links open the entity.
        item.tapAction = .url("https://camera/porch")
        #expect(!item.widgetTapInteractionType.opensEntityInApp)
        item.tapAction = .url("https://example.com/?more-info-entity-id=light.kitchen")
        #expect(!item.widgetTapInteractionType.opensEntityInApp)
        item.tapAction = .moreInfoDialog
        #expect(item.widgetTapInteractionType.opensEntityInApp)
    }

    /// A camera opens in the app's own player rather than the frontend's more-info dialog, and that
    /// is still only opening the entity, so it is exempt from confirmation too.
    @Test func cameraOpensTheNativePlayer() {
        let camera = MagicItem(id: "camera.porch", serverId: "1", type: .entity)

        #expect(camera.defaultIconAction == .moreInfoDialog)
        #expect(!camera.controlsEntityFromWidget)
        #expect(camera.widgetInteractionType == camera.widgetTapInteractionType)
        #expect(camera.widgetInteractionType.opensEntityInApp)

        guard case let .widgetURL(url) = camera.widgetInteractionType else {
            Issue.record("Expected a deep link, got \(camera.widgetInteractionType)")
            return
        }
        #expect(url.host == AppConstants.cameraDeeplinkHost)
        #expect(url.absoluteString.contains("entityId=camera.porch"))
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
