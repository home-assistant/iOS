import Foundation
@testable import Shared
import Testing

/// `MagicItem` identity, icons and names, and the `ItemAction` metadata the customization screen
/// shows. The widget tap routing itself is covered by `MagicItemWidgetInteractionTests`.
struct MagicItemCoverageTests {
    private func info(iconName: String = "") -> MagicItem.Info {
        .init(id: "1-item", name: "Info name", iconName: iconName)
    }

    // MARK: - Identity

    @Test func equalityIsIdentityWhileContentEqualityComparesEverything() {
        let item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        var renamed = item
        renamed.displayText = "Kitchen"

        #expect(item == renamed)
        #expect(Set([item, renamed]).count == 1)
        #expect(item.contentEquals(item))
        #expect(!item.contentEquals(renamed))
        #expect(item.contentHash == MagicItem(id: "light.kitchen", serverId: "1", type: .entity).contentHash)
        #expect(item.contentHash != renamed.contentHash)

        let otherServer = MagicItem(id: "light.kitchen", serverId: "2", type: .entity)
        #expect(item != otherServer)
        #expect(!item.contentEquals(otherServer))
    }

    @Test func folderContentHashFollowsItsChildren() {
        let child = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        var renamedChild = child
        renamedChild.displayText = "Kitchen"

        let folder = MagicItem(id: "folder", serverId: "1", type: .folder, items: [child])
        let editedFolder = MagicItem(id: "folder", serverId: "1", type: .folder, items: [renamedChild])
        #expect(folder == editedFolder)
        #expect(folder.contentHash != editedFolder.contentHash)
        #expect(!folder.contentEquals(editedFolder))
    }

    @Test func serverUniqueIdJoinsServerAndId() {
        #expect(MagicItem(id: "script.open_gate", serverId: "EB1364", type: .script).serverUniqueId
            == "EB1364-script.open_gate")
    }

    @Test func assistItemsAreRecognized() {
        #expect(MagicItem(id: "pipeline", serverId: "1", type: .assistPipeline).isAssist)
        #expect(MagicItem(id: "prompt", serverId: "1", type: .assistPrompt).isAssist)
        #expect(!MagicItem(id: "light.kitchen", serverId: "1", type: .entity).isAssist)
        #expect(!MagicItem(id: "folder", serverId: "1", type: .folder).isAssist)
    }

    @Test func storedItemsMatchOnTheirServerExceptAssistPrompts() {
        let light = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(light.isSameStoredItem(as: MagicItem(id: "light.kitchen", serverId: "1", type: .entity)))
        #expect(!light.isSameStoredItem(as: MagicItem(id: "light.kitchen", serverId: "2", type: .entity)))
        #expect(!light.isSameStoredItem(as: MagicItem(id: "light.office", serverId: "1", type: .entity)))

        let prompt = MagicItem(id: "prompt-1", serverId: "1", type: .assistPrompt)
        #expect(prompt.isSameStoredItem(as: MagicItem(id: "prompt-1", serverId: "2", type: .assistPrompt)))
        #expect(!prompt.isSameStoredItem(as: MagicItem(id: "prompt-1", serverId: "2", type: .entity)))
    }

    @Test func domainComesFromTheId() {
        #expect(MagicItem(id: "light.kitchen", serverId: "1", type: .entity).domain == .light)
        #expect(MagicItem(id: "script.open_gate", serverId: "1", type: .script).domain == .script)
        #expect(MagicItem(id: "not_a_domain.thing", serverId: "1", type: .entity).domain == nil)
        #expect(MagicItem(id: "", serverId: "1", type: .folder).domain == nil)
    }

    @Test func watchDisplayOnlyIsLimitedToSensorEntities() {
        #expect(MagicItem(id: "sensor.power", serverId: "1", type: .entity).isWatchDisplayOnly)
        #expect(MagicItem(id: "binary_sensor.door", serverId: "1", type: .entity).isWatchDisplayOnly)
        #expect(!MagicItem(id: "light.kitchen", serverId: "1", type: .entity).isWatchDisplayOnly)
        #expect(!MagicItem(id: "sensor.power", serverId: "1", type: .script).isWatchDisplayOnly)
    }

    // MARK: - Coding

    @Test func unknownItemTypesDecodeAsUnsupported() throws {
        let json = Data(#"{"id":"x","serverId":"1","type":"something_new"}"#.utf8)
        let item = try JSONDecoder().decode(MagicItem.self, from: json)
        #expect(item.type == .unsupported)
        #expect(item.id == "x")
        #expect(item.customization == nil)
        #expect(item.action == nil)
    }

    @Test func itemsRoundTripThroughCoding() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            customization: .init(iconColor: "FF0000", requiresConfirmation: true, icon: "mdi:sofa"),
            action: .navigate("/lovelace/0"),
            tapAction: .runScript("1", "script.open_gate"),
            displayText: "Kitchen",
            assistPrompt: "Turn it on",
            assistPipelineId: "pipeline"
        )
        let decoded = try JSONDecoder().decode(MagicItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.contentEquals(item))

        for type in [
            MagicItem.ItemType.script,
            .scene,
            .entity,
            .folder,
            .area,
            .assistPipeline,
            .assistPrompt,
            .complication,
        ] {
            let data = try JSONEncoder().encode([type])
            let decodedTypes = try JSONDecoder().decode([MagicItem.ItemType].self, from: data)
            #expect(decodedTypes == [type])
        }
    }

    // MARK: - Icons and names

    @Test func iconsFollowTheItemType() {
        func icon(_ type: MagicItem.ItemType, iconName: String = "") -> MaterialDesignIcons {
            MagicItem(id: "item", serverId: "1", type: type, customization: nil).icon(info: info(iconName: iconName))
        }

        #expect(icon(.scene, iconName: "palette") == .paletteIcon)
        #expect(icon(.scene, iconName: "not_an_icon") == .scriptTextOutlineIcon)
        #expect(icon(.script, iconName: "mdi:script-text") == .scriptTextIcon)
        #expect(icon(.entity, iconName: "mdi:lightbulb") == .lightbulbIcon)
        #expect(icon(.entity, iconName: "mdi:not-an-icon") == .dotsGridIcon)
        #expect(icon(.folder) == .folderIcon)
        #expect(icon(.area, iconName: "mdi:sofa") == .sofaIcon)
        #expect(icon(.area) == .textureBoxIcon)
        #expect(icon(.complication, iconName: "mdi:thermometer") == .thermometerIcon)
        #expect(icon(.complication) == .watchIcon)
        #expect(icon(.assistPipeline) == .microphoneIcon)
        #expect(icon(.assistPrompt) == .messageProcessingOutlineIcon)
        #expect(icon(.unsupported) == .dotsGridIcon)
    }

    @Test func customIconWinsAndFallsBackToTheGrid() {
        let custom = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            customization: .init(icon: MaterialDesignIcons.sofaIcon.name)
        )
        #expect(custom.icon(info: info(iconName: "mdi:lightbulb")) == .sofaIcon)

        let unknown = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            customization: .init(icon: "not_an_icon")
        )
        #expect(unknown.icon(info: info(iconName: "mdi:lightbulb")) == .dotsGridIcon)
    }

    @Test func displayTextWinsOverTheInfoName() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(item.name(info: info()) == "Info name")
        item.displayText = "Kitchen"
        #expect(item.name(info: info()) == "Kitchen")
    }

    // MARK: - Customization

    @Test func customizationColors() {
        var customization = MagicItem.Customization()
        #expect(!customization.useCustomColors)
        #expect(customization.customIconColor == nil)

        customization.textColor = "FFFFFF"
        #expect(customization.useCustomColors)

        customization.useCustomIconColor("#00AEF8")
        #expect(customization.iconColorIsCustomized == true)
        #expect(customization.customIconColor == "#00AEF8")

        customization.useDefaultIconColor()
        #expect(customization.iconColor == nil)
        #expect(customization.iconColorIsCustomized == false)

        // Seeded tints saved without the flag aren't a choice the user made.
        #expect(MagicItem.Customization(iconColor: "#00aef8ff").customIconColor == nil)
        #expect(MagicItem.Customization(iconColor: "#123456").customIconColor == "#123456")
    }

    @Test func hexNormalizationIgnoresPrefixCaseAndOpaqueAlpha() {
        #expect(MagicItem.normalizedHex("#00aef8") == "00AEF8")
        #expect(MagicItem.normalizedHex("00AEF8FF") == "00AEF8")
        #expect(MagicItem.normalizedHex("#00AEF880") == "00AEF880")
        #expect(MagicItem.seededIconColorHexes.contains("00AEF8"))
        #expect(MagicItem.seededIconColorHexes.contains(MagicItem.normalizedHex(MagicItem.defaultIconColorHex)))
        #expect(!MagicItem.defaultIconColorHex.isEmpty)
        #expect(MagicItem.defaultAssistIconColorHex == MagicItem.defaultIconColorHex)
    }

    @Test func infoTakesAnEditedCustomization() {
        let base = MagicItem.Info(
            id: "1-light.kitchen",
            name: "Kitchen",
            iconName: "mdi:lightbulb",
            contextSubtitle: "Kitchen • Ceiling"
        )
        let customization = MagicItem.Customization(textColor: "FFFFFF")
        let edited = base.replacingCustomization(customization)
        #expect(edited.customization == customization)
        #expect(edited.id == base.id)
        #expect(edited.name == base.name)
        #expect(edited.iconName == base.iconName)
        #expect(edited.contextSubtitle == base.contextSubtitle)
    }

    // MARK: - ItemAction

    @Test func everyActionHasItsOwnIdAndName() {
        let ids = ItemAction.allCases.map(\.id)
        #expect(Set(ids).count == ItemAction.allCases.count)
        #expect(ids == [
            "default",
            "moreInfoDialog",
            "toggle",
            "mainAction",
            "turnOn",
            "turnOff",
            "navigate",
            "url",
            "performAction",
            "runScript",
            "assist",
            "nothing",
        ])
        for action in ItemAction.allCases {
            #expect(!action.name.isEmpty, "\(action.id)")
        }
        #expect(Set(ItemAction.allCases.map(\.name)).count == ItemAction.allCases.count)
    }

    @Test func domainBehaviorsTakeTheDomainsWords() {
        #expect(ItemAction.mainAction.name(for: .button) == Domain.button.mainActionName)
        #expect(ItemAction.mainAction.name(for: nil) == ItemAction.mainAction.name)
        #expect(ItemAction.turnOn.name(for: .lock) == Service.unlock.toggleActionName)
        #expect(ItemAction.turnOff.name(for: .lock) == Service.lock.toggleActionName)
        #expect(ItemAction.turnOn.name(for: .sensor) == ItemAction.turnOn.name)
        #expect(ItemAction.turnOff.name(for: nil) == ItemAction.turnOff.name)
        #expect(ItemAction.toggle.name(for: .lock) == ItemAction.toggle.name)
        #expect(ItemAction.defaultName(resolvingTo: "Toggle").contains("Toggle"))
    }

    @Test func typedAddressesGetAScheme() {
        #expect(ItemAction.resolvedURL(from: "") == nil)
        #expect(ItemAction.resolvedURL(from: "   ") == nil)
        #expect(ItemAction.resolvedURL(from: " example.com/page ") == URL(string: "https://example.com/page"))
        #expect(ItemAction.resolvedURL(from: "http://example.com") == URL(string: "http://example.com"))
        #expect(
            ItemAction.resolvedURL(from: "homeassistant://navigate/lovelace")
                == URL(string: "homeassistant://navigate/lovelace")
        )
    }

    @Test func offeredActionsDropWhatTheDomainCannotDo() {
        let sensor = MagicItem(id: "sensor.power", serverId: "1", type: .entity)
        let offered = ItemAction.offered(for: sensor, selected: .default).map(\.id)
        #expect(!offered.contains("toggle"))
        #expect(!offered.contains("mainAction"))
        #expect(!offered.contains("turnOn"))
        #expect(offered.contains("navigate"))

        // A stored choice stays listed even when it no longer applies.
        let keptToggle = ItemAction.offered(for: sensor, selected: .toggle).map(\.id)
        #expect(keptToggle.contains("toggle"))

        let lock = MagicItem(id: "lock.front", serverId: "1", type: .entity)
        let lockOffered = ItemAction.offered(for: lock, selected: .default).map(\.id)
        #expect(lockOffered.contains("toggle"))
        #expect(lockOffered.contains("turnOn"))
        #expect(lockOffered.contains("turnOff"))
    }

    // MARK: - Interactions not covered elsewhere

    @Test func navigateActionOpensThePathOnTheItemsServer() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            action: .navigate("/lovelace/0")
        )
        let expected = try #require(AppConstants.navigateDeeplinkURL(
            path: "lovelace/0",
            serverId: "1",
            avoidUnnecessaryReload: true
        ))
        #expect(item.widgetInteractionType == .widgetURL(expected))
        #expect(!item.controlsEntityFromWidget)
    }

    @Test func runScriptActionActivatesTheScript() {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            action: .runScript("2", "script.open_gate")
        )
        #expect(item.widgetInteractionType == .appIntent(.activate(
            entityId: "script.open_gate",
            domain: "script",
            serverId: "2"
        )))
        #expect(item.controlsEntityFromWidget)
    }

    @Test func assistActionOpensAssist() throws {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            action: .assist("1", "pipeline", true)
        )
        let expected = try #require(AppConstants.assistDeeplinkURL(
            serverId: "1",
            pipelineId: "pipeline",
            startListening: true
        ))
        #expect(item.widgetInteractionType == .widgetURL(expected))
    }

    @Test func moreInfoOnAnItemWithoutAnEntityFallsBack() {
        let folder = MagicItem(id: "folder", serverId: "1", type: .folder, action: .moreInfoDialog)
        #expect(folder.widgetInteractionType == folder.widgetTapInteractionType)
        #expect(!folder.hasMoreInfoDialog)
        #expect(folder.defaultTapAction == folder.defaultIconAction)
    }
}
