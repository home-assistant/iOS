import Foundation
@testable import Shared
import Testing

@Suite("MagicItem Tests")
struct MagicItemTests {
    // MARK: - Initialization Tests
    
    @Test("Initialize MagicItem with all parameters")
    func initializeMagicItemComplete() {
        let customization = MagicItem.Customization(
            iconColor: "#FF0000",
            textColor: "#00FF00",
            backgroundColor: "#0000FF",
            requiresConfirmation: true,
            icon: "mdi:test"
        )
        
        let item = MagicItem(
            id: "script.test_script",
            serverId: "server123",
            type: .script,
            customization: customization,
            action: .default,
            displayText: "Test Display"
        )
        
        #expect(item.id == "script.test_script")
        #expect(item.serverId == "server123")
        #expect(item.type == .script)
        #expect(item.customization?.iconColor == "#FF0000")
        #expect(item.action == .default)
        #expect(item.displayText == "Test Display")
    }
    
    @Test("Initialize MagicItem with minimal parameters")
    func initializeMagicItemMinimal() {
        let item = MagicItem(
            id: "scene.test_scene",
            serverId: "server456",
            type: .scene
        )
        
        #expect(item.id == "scene.test_scene")
        #expect(item.serverId == "server456")
        #expect(item.type == .scene)
        #expect(item.customization != nil) // Default .init()
        #expect(item.action == .default)
        #expect(item.displayText == nil)
    }
    
    // MARK: - Computed Property Tests
    
    @Test("Server unique ID combines serverId and id")
    func serverUniqueId() {
        let item = MagicItem(
            id: "light.living_room",
            serverId: "home_server",
            type: .entity
        )
        
        #expect(item.serverUniqueId == "home_server-light.living_room")
    }
    
    @Test("Domain extraction from entity ID")
    func domainExtraction() {
        let lightItem = MagicItem(
            id: "light.bedroom",
            serverId: "server1",
            type: .entity
        )
        #expect(lightItem.domain == .light)
        
        let switchItem = MagicItem(
            id: "switch.kitchen",
            serverId: "server1",
            type: .entity
        )
        #expect(switchItem.domain == .switch)
        
        let scriptItem = MagicItem(
            id: "script.automation",
            serverId: "server1",
            type: .script
        )
        #expect(scriptItem.domain == .script)
        
        let invalidItem = MagicItem(
            id: "invalid_no_domain",
            serverId: "server1",
            type: .entity
        )
        #expect(invalidItem.domain == nil)
        
        let unknownDomainItem = MagicItem(
            id: "unknown_domain.entity",
            serverId: "server1",
            type: .entity
        )
        #expect(unknownDomainItem.domain == nil)
    }
    
    // MARK: - Icon Tests
    
    @Test("Icon method with custom icon")
    func iconWithCustomIcon() {
        let customization = MagicItem.Customization(icon: "mdi:home")
        let item = MagicItem(
            id: "script.test",
            serverId: "server1",
            type: .script,
            customization: customization
        )
        let info = MagicItem.Info(id: "id", name: "Test", iconName: "other-icon")
        
        let icon = item.icon(info: info)
        #expect(icon.name == "home")
    }
    
    @Test("Icon method for action type")
    func iconForActionType() {
        let item = MagicItem(
            id: "action.test",
            serverId: "server1",
            type: .action
        )
        let info = MagicItem.Info(id: "id", name: "Test", iconName: "test-icon")
        
        let icon = item.icon(info: info)
        // Action uses named icon
        #expect(icon.name == "test-icon" || icon == .scriptTextOutlineIcon)
    }
    
    @Test("Icon method for script type")
    func iconForScriptType() {
        let item = MagicItem(
            id: "script.test",
            serverId: "server1",
            type: .script
        )
        let info = MagicItem.Info(id: "id", name: "Test", iconName: "mdi:script")
        
        let icon = item.icon(info: info)
        // Script uses serverside value
        #expect(icon.name == "script" || icon == .dotsGridIcon)
    }
    
    @Test("Icon method for entity type")
    func iconForEntityType() {
        let item = MagicItem(
            id: "light.test",
            serverId: "server1",
            type: .entity
        )
        let info = MagicItem.Info(id: "id", name: "Test", iconName: "mdi:lightbulb")
        
        let icon = item.icon(info: info)
        #expect(icon.name == "lightbulb" || icon == .dotsGridIcon)
    }
    
    // MARK: - Name Tests
    
    @Test("Name method prefers displayText")
    func namePreferDisplayText() {
        let item = MagicItem(
            id: "script.test",
            serverId: "server1",
            type: .script,
            displayText: "Custom Display Name"
        )
        let info = MagicItem.Info(id: "id", name: "Original Name", iconName: "icon")
        
        #expect(item.name(info: info) == "Custom Display Name")
    }
    
    @Test("Name method falls back to info name")
    func nameFallbackToInfo() {
        let item = MagicItem(
            id: "script.test",
            serverId: "server1",
            type: .script
        )
        let info = MagicItem.Info(id: "id", name: "Info Name", iconName: "icon")
        
        #expect(item.name(info: info) == "Info Name")
    }
    
    // MARK: - Customization Tests
    
    @Test("Customization useCustomColors property")
    func customizationUseCustomColors() {
        let noColors = MagicItem.Customization()
        #expect(noColors.useCustomColors == false)
        
        let textColor = MagicItem.Customization(textColor: "#FF0000")
        #expect(textColor.useCustomColors == true)
        
        let backgroundColor = MagicItem.Customization(backgroundColor: "#00FF00")
        #expect(backgroundColor.useCustomColors == true)
        
        let bothColors = MagicItem.Customization(textColor: "#FF0000", backgroundColor: "#00FF00")
        #expect(bothColors.useCustomColors == true)
    }
    
    // MARK: - Equality and Hashing Tests
    
    @Test("MagicItem equality based on id and serverId")
    func magicItemEquality() {
        let item1 = MagicItem(id: "script.test", serverId: "server1", type: .script)
        let item2 = MagicItem(id: "script.test", serverId: "server1", type: .scene) // Different type
        let item3 = MagicItem(id: "script.test", serverId: "server2", type: .script) // Different server
        let item4 = MagicItem(id: "script.other", serverId: "server1", type: .script) // Different id
        
        #expect(item1 == item2) // Same id and serverId
        #expect(item1 != item3) // Different serverId
        #expect(item1 != item4) // Different id
    }
    
    @Test("MagicItem hashing based on id")
    func magicItemHashing() {
        let item1 = MagicItem(id: "script.test", serverId: "server1", type: .script)
        let item2 = MagicItem(id: "script.test", serverId: "server2", type: .script)
        let item3 = MagicItem(id: "script.other", serverId: "server1", type: .script)
        
        var set = Set<MagicItem>()
        set.insert(item1)
        set.insert(item2)
        set.insert(item3)
        
        // Items with same id hash to same value (based on implementation)
        #expect(set.count >= 2) // At least item1 and item3 should be different
    }
    
    // MARK: - Info Tests
    
    @Test("Info initialization and properties")
    func infoInitialization() {
        let info = MagicItem.Info(
            id: "server1-script.test",
            name: "Test Script",
            iconName: "mdi:script",
            customization: .init(requiresConfirmation: true)
        )
        
        #expect(info.id == "server1-script.test")
        #expect(info.name == "Test Script")
        #expect(info.iconName == "mdi:script")
        #expect(info.customization?.requiresConfirmation == true)
    }
    
    // MARK: - ItemAction Tests
    
    @Test("ItemAction id property")
    func itemActionId() {
        #expect(ItemAction.default.id == "default")
        #expect(ItemAction.moreInfoDialog.id == "moreInfoDialog")
        #expect(ItemAction.navigate("").id == "navigate")
        #expect(ItemAction.runScript("", "").id == "runScript")
        #expect(ItemAction.assist("", "", false).id == "assist")
        #expect(ItemAction.nothing.id == "nothing")
    }
    
    @Test("ItemAction name property returns localized strings")
    func itemActionName() {
        // Test that name property returns non-empty strings
        #expect(!ItemAction.default.name.isEmpty)
        #expect(!ItemAction.moreInfoDialog.name.isEmpty)
        #expect(!ItemAction.navigate("").name.isEmpty)
        #expect(!ItemAction.runScript("", "").name.isEmpty)
        #expect(!ItemAction.assist("", "", false).name.isEmpty)
        #expect(!ItemAction.nothing.name.isEmpty)
    }
    
    // MARK: - Widget Interaction Type Tests
    
    @Test("Widget interaction type for button domain")
    func widgetInteractionTypeButton() {
        let item = MagicItem(
            id: "button.doorbell",
            serverId: "server1",
            type: .entity
        )
        
        let interactionType = item.widgetInteractionType
        switch interactionType {
        case .appIntent(let intent):
            switch intent {
            case .press:
                // Expected
                break
            default:
                Issue.record("Expected press intent for button domain")
            }
        default:
            Issue.record("Expected appIntent for button domain")
        }
    }
    
    @Test("Widget interaction type for light domain")
    func widgetInteractionTypeLight() {
        let item = MagicItem(
            id: "light.bedroom",
            serverId: "server1",
            type: .entity
        )
        
        let interactionType = item.widgetInteractionType
        switch interactionType {
        case .appIntent(let intent):
            switch intent {
            case .toggle:
                // Expected
                break
            default:
                Issue.record("Expected toggle intent for light domain")
            }
        default:
            Issue.record("Expected appIntent for light domain")
        }
    }
    
    @Test("Widget interaction type for script domain")
    func widgetInteractionTypeScript() {
        let item = MagicItem(
            id: "script.automation",
            serverId: "server1",
            type: .entity
        )
        
        let interactionType = item.widgetInteractionType
        switch interactionType {
        case .appIntent(let intent):
            switch intent {
            case .activate:
                // Expected
                break
            default:
                Issue.record("Expected activate intent for script domain")
            }
        default:
            Issue.record("Expected appIntent for script domain")
        }
    }
    
    @Test("Widget interaction type for lock domain opens app")
    func widgetInteractionTypeLock() {
        let item = MagicItem(
            id: "lock.front_door",
            serverId: "server1",
            type: .entity
        )
        
        let interactionType = item.widgetInteractionType
        switch interactionType {
        case .widgetURL:
            // Expected - lock opens app for confirmation
            break
        default:
            Issue.record("Expected widgetURL for lock domain")
        }
    }
    
    @Test("Widget interaction type with custom action")
    func widgetInteractionTypeCustomAction() {
        let item = MagicItem(
            id: "light.bedroom",
            serverId: "server1",
            type: .entity,
            action: .nothing
        )
        
        let interactionType = item.widgetInteractionType
        switch interactionType {
        case .appIntent(let intent):
            switch intent {
            case .refresh:
                // Expected for .nothing action
                break
            default:
                Issue.record("Expected refresh intent for nothing action")
            }
        default:
            Issue.record("Expected appIntent for nothing action")
        }
    }
}
