import Foundation
import GRDB
@testable import Shared
import Testing

@Suite("MagicItemProvider Tests")
struct MagicItemProviderTests {
    // MARK: - Protocol Tests
    
    @Test("MagicItemProvider conforms to protocol")
    func providerConformsToProtocol() {
        let provider: MagicItemProviderProtocol = MagicItemProvider()
        #expect(provider is MagicItemProvider)
    }
    
    // MARK: - GetInfo Tests
    
    @Test("GetInfo returns nil for non-existent action")
    func getInfoNonExistentAction() async throws {
        let provider = MagicItemProvider()
        let item = MagicItem(
            id: "non_existent_action",
            serverId: "server1",
            type: .action
        )
        
        let info = provider.getInfo(for: item)
        #expect(info == nil, "Should return nil for non-existent action")
    }
    
    @Test("GetInfo returns nil for non-existent script")
    func getInfoNonExistentScript() async throws {
        let provider = MagicItemProvider()
        provider.entitiesPerServer = [
            "server1": []
        ]
        
        let item = MagicItem(
            id: "script.non_existent",
            serverId: "server1",
            type: .script
        )
        
        let info = provider.getInfo(for: item)
        #expect(info == nil, "Should return nil for non-existent script")
    }
    
    @Test("GetInfo returns info for script")
    func getInfoForScript() async throws {
        let provider = MagicItemProvider()
        let scriptEntity = HAAppEntity(
            id: "server1-script.test",
            entityId: "script.test",
            serverId: "server1",
            domain: Domain.script.rawValue,
            name: "Test Script",
            icon: "mdi:script"
        )
        provider.entitiesPerServer = [
            "server1": [scriptEntity]
        ]
        
        let item = MagicItem(
            id: "script.test",
            serverId: "server1",
            type: .script
        )
        
        let info = provider.getInfo(for: item)
        #expect(info != nil, "Should return info for existing script")
        #expect(info?.name == "Test Script")
        #expect(info?.iconName == "mdi:script")
    }
    
    @Test("GetInfo returns info for scene")
    func getInfoForScene() async throws {
        let provider = MagicItemProvider()
        let sceneEntity = HAAppEntity(
            id: "server1-scene.movie_night",
            entityId: "scene.movie_night",
            serverId: "server1",
            domain: Domain.scene.rawValue,
            name: "Movie Night",
            icon: "mdi:movie"
        )
        provider.entitiesPerServer = [
            "server1": [sceneEntity]
        ]
        
        let item = MagicItem(
            id: "scene.movie_night",
            serverId: "server1",
            type: .scene
        )
        
        let info = provider.getInfo(for: item)
        #expect(info != nil, "Should return info for existing scene")
        #expect(info?.name == "Movie Night")
        #expect(info?.iconName == "mdi:movie")
    }
    
    @Test("GetInfo returns info for entity")
    func getInfoForEntity() async throws {
        let provider = MagicItemProvider()
        let lightEntity = HAAppEntity(
            id: "server1-light.bedroom",
            entityId: "light.bedroom",
            serverId: "server1",
            domain: Domain.light.rawValue,
            name: "Bedroom Light",
            icon: "mdi:lightbulb"
        )
        provider.entitiesPerServer = [
            "server1": [lightEntity]
        ]
        
        let item = MagicItem(
            id: "light.bedroom",
            serverId: "server1",
            type: .entity
        )
        
        let info = provider.getInfo(for: item)
        #expect(info != nil, "Should return info for existing entity")
        #expect(info?.name == "Bedroom Light")
        #expect(info?.iconName == "mdi:lightbulb")
    }
    
    @Test("GetInfo uses default icon when entity icon is nil")
    func getInfoDefaultIcon() async throws {
        let provider = MagicItemProvider()
        let lightEntity = HAAppEntity(
            id: "server1-light.bedroom",
            entityId: "light.bedroom",
            serverId: "server1",
            domain: Domain.light.rawValue,
            name: "Bedroom Light",
            icon: nil
        )
        provider.entitiesPerServer = [
            "server1": [lightEntity]
        ]
        
        let item = MagicItem(
            id: "light.bedroom",
            serverId: "server1",
            type: .entity
        )
        
        let info = provider.getInfo(for: item)
        #expect(info != nil, "Should return info for entity")
        // Should use domain default icon
        #expect(!info!.iconName.isEmpty)
    }
    
    @Test("GetInfo returns nil for entity not in cache")
    func getInfoEntityNotInCache() async throws {
        let provider = MagicItemProvider()
        provider.entitiesPerServer = [
            "server1": []
        ]
        
        let item = MagicItem(
            id: "light.bedroom",
            serverId: "server1",
            type: .entity
        )
        
        let info = provider.getInfo(for: item)
        #expect(info == nil, "Should return nil for entity not in cache")
    }
    
    @Test("GetInfo returns nil for wrong server")
    func getInfoWrongServer() async throws {
        let provider = MagicItemProvider()
        let scriptEntity = HAAppEntity(
            id: "server1-script.test",
            entityId: "script.test",
            serverId: "server1",
            domain: Domain.script.rawValue,
            name: "Test Script",
            icon: "mdi:script"
        )
        provider.entitiesPerServer = [
            "server1": [scriptEntity]
        ]
        
        let item = MagicItem(
            id: "script.test",
            serverId: "server2", // Different server
            type: .script
        )
        
        let info = provider.getInfo(for: item)
        #expect(info == nil, "Should return nil for wrong server")
    }
    
    @Test("GetInfo preserves customization for script")
    func getInfoPreservesCustomization() async throws {
        let provider = MagicItemProvider()
        let scriptEntity = HAAppEntity(
            id: "server1-script.test",
            entityId: "script.test",
            serverId: "server1",
            domain: Domain.script.rawValue,
            name: "Test Script",
            icon: "mdi:script"
        )
        provider.entitiesPerServer = [
            "server1": [scriptEntity]
        ]
        
        let customization = MagicItem.Customization(
            iconColor: "#FF0000",
            requiresConfirmation: true
        )
        let item = MagicItem(
            id: "script.test",
            serverId: "server1",
            type: .script,
            customization: customization
        )
        
        let info = provider.getInfo(for: item)
        #expect(info != nil)
        #expect(info?.customization?.iconColor == "#FF0000")
        #expect(info?.customization?.requiresConfirmation == true)
    }
    
    // MARK: - Migration Tests
    
    @Test("MigrateItemsIfNeeded returns items unchanged when all infos exist")
    func migrateItemsNoChangesNeeded() async throws {
        let provider = MagicItemProvider()
        let scriptEntity = HAAppEntity(
            id: "server1-script.test",
            entityId: "script.test",
            serverId: "server1",
            domain: Domain.script.rawValue,
            name: "Test Script",
            icon: "mdi:script"
        )
        provider.entitiesPerServer = [
            "server1": [scriptEntity]
        ]
        
        let items = [
            MagicItem(id: "script.test", serverId: "server1", type: .script)
        ]
        
        let migratedItems = provider.migrateItemsIfNeeded(items: items)
        #expect(migratedItems.count == 1)
        #expect(migratedItems[0].id == "script.test")
        #expect(migratedItems[0].serverId == "server1")
    }
    
    @Test("MigrateItemsIfNeeded migrates entity to new server")
    func migrateItemsToNewServer() async throws {
        let provider = MagicItemProvider()
        let scriptEntity = HAAppEntity(
            id: "server2-script.test",
            entityId: "script.test",
            serverId: "server2",
            domain: Domain.script.rawValue,
            name: "Test Script",
            icon: "mdi:script"
        )
        provider.entitiesPerServer = [
            "server2": [scriptEntity]
        ]
        
        let items = [
            MagicItem(id: "script.test", serverId: "server1", type: .script) // Old server
        ]
        
        let migratedItems = provider.migrateItemsIfNeeded(items: items)
        #expect(migratedItems.count == 1)
        #expect(migratedItems[0].id == "script.test")
        // Should migrate to server2
        #expect(migratedItems[0].serverId == "server2")
    }
    
    @Test("MigrateItemsIfNeeded keeps action unchanged")
    func migrateItemsKeepsAction() async throws {
        let provider = MagicItemProvider()
        provider.entitiesPerServer = [:]
        
        let customization = MagicItem.Customization(iconColor: "#FF0000")
        let items = [
            MagicItem(
                id: "action.test",
                serverId: "server1",
                type: .action,
                customization: customization
            )
        ]
        
        let migratedItems = provider.migrateItemsIfNeeded(items: items)
        #expect(migratedItems.count == 1)
        #expect(migratedItems[0].id == "action.test")
        #expect(migratedItems[0].serverId == "server1")
        #expect(migratedItems[0].type == .action)
        #expect(migratedItems[0].customization?.iconColor == "#FF0000")
    }
    
    @Test("MigrateItemsIfNeeded returns original item when no replacement found")
    func migrateItemsNoReplacementFound() async throws {
        let provider = MagicItemProvider()
        provider.entitiesPerServer = [
            "server2": []
        ]
        
        let items = [
            MagicItem(id: "script.nonexistent", serverId: "server1", type: .script)
        ]
        
        let migratedItems = provider.migrateItemsIfNeeded(items: items)
        #expect(migratedItems.count == 1)
        #expect(migratedItems[0].id == "script.nonexistent")
        // Should keep original server when no replacement found
        #expect(migratedItems[0].serverId == "server1")
    }
    
    @Test("MigrateItemsIfNeeded handles mixed items")
    func migrateItemsMixed() async throws {
        let provider = MagicItemProvider()
        let scriptEntity1 = HAAppEntity(
            id: "server1-script.test1",
            entityId: "script.test1",
            serverId: "server1",
            domain: Domain.script.rawValue,
            name: "Test Script 1",
            icon: "mdi:script"
        )
        let scriptEntity2 = HAAppEntity(
            id: "server2-script.test2",
            entityId: "script.test2",
            serverId: "server2",
            domain: Domain.script.rawValue,
            name: "Test Script 2",
            icon: "mdi:script"
        )
        provider.entitiesPerServer = [
            "server1": [scriptEntity1],
            "server2": [scriptEntity2]
        ]
        
        let items = [
            MagicItem(id: "script.test1", serverId: "server1", type: .script), // Exists
            MagicItem(id: "script.test2", serverId: "server1", type: .script), // Needs migration
            MagicItem(id: "action.test", serverId: "server1", type: .action)   // Action
        ]
        
        let migratedItems = provider.migrateItemsIfNeeded(items: items)
        #expect(migratedItems.count == 3)
        #expect(migratedItems[0].serverId == "server1") // Unchanged
        #expect(migratedItems[1].serverId == "server2") // Migrated
        #expect(migratedItems[2].serverId == "server1") // Action unchanged
    }
    
    @Test("MigrateItemsIfNeeded preserves customization during migration")
    func migrateItemsPreservesCustomization() async throws {
        let provider = MagicItemProvider()
        let scriptEntity = HAAppEntity(
            id: "server2-script.test",
            entityId: "script.test",
            serverId: "server2",
            domain: Domain.script.rawValue,
            name: "Test Script",
            icon: "mdi:script"
        )
        provider.entitiesPerServer = [
            "server2": [scriptEntity]
        ]
        
        let customization = MagicItem.Customization(
            iconColor: "#FF0000",
            requiresConfirmation: true,
            icon: "mdi:custom"
        )
        let items = [
            MagicItem(
                id: "script.test",
                serverId: "server1",
                type: .script,
                customization: customization
            )
        ]
        
        let migratedItems = provider.migrateItemsIfNeeded(items: items)
        #expect(migratedItems.count == 1)
        #expect(migratedItems[0].serverId == "server2")
        #expect(migratedItems[0].customization?.iconColor == "#FF0000")
        #expect(migratedItems[0].customization?.requiresConfirmation == true)
        #expect(migratedItems[0].customization?.icon == "mdi:custom")
    }
    
    // MARK: - Edge Cases
    
    @Test("GetInfo handles empty entities cache")
    func getInfoEmptyCache() async throws {
        let provider = MagicItemProvider()
        provider.entitiesPerServer = [:]
        
        let item = MagicItem(
            id: "light.bedroom",
            serverId: "server1",
            type: .entity
        )
        
        let info = provider.getInfo(for: item)
        #expect(info == nil, "Should return nil when cache is empty")
    }
    
    @Test("MigrateItemsIfNeeded handles empty input")
    func migrateItemsEmptyInput() async throws {
        let provider = MagicItemProvider()
        provider.entitiesPerServer = [:]
        
        let items: [MagicItem] = []
        let migratedItems = provider.migrateItemsIfNeeded(items: items)
        
        #expect(migratedItems.isEmpty)
    }
    
    @Test("EntitiesPerServer can be set and retrieved")
    func entitiesPerServerAccessible() async throws {
        let provider = MagicItemProvider()
        let entity = HAAppEntity(
            id: "server1-light.test",
            entityId: "light.test",
            serverId: "server1",
            domain: Domain.light.rawValue,
            name: "Test Light",
            icon: nil
        )
        
        provider.entitiesPerServer = ["server1": [entity]]
        
        #expect(provider.entitiesPerServer.count == 1)
        #expect(provider.entitiesPerServer["server1"]?.count == 1)
        #expect(provider.entitiesPerServer["server1"]?[0].entityId == "light.test")
    }
}
