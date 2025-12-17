import Foundation
@testable import Shared
import Testing

struct CarPlayConfigExportImportTests {
    @Test func testCarPlayConfigEncodingDecoding() throws {
        // Create a test configuration
        let config = CarPlayConfig(
            id: "carplay-config",
            tabs: [.quickAccess, .areas, .domains],
            quickAccessItems: [
                .init(
                    id: "script.test_script",
                    serverId: "test-server-id",
                    type: .script,
                    customization: .init(
                        iconColor: "FF0000",
                        requiresConfirmation: true
                    )
                ),
                .init(
                    id: "scene.test_scene",
                    serverId: "test-server-id",
                    type: .scene
                ),
            ]
        )

        // Test encoding
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        #expect(data.count > 0, "Encoded data should not be empty")

        // Test decoding
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(CarPlayConfig.self, from: data)

        // Verify configuration matches
        #expect(decodedConfig.id == config.id, "Config ID should match")
        #expect(decodedConfig.tabs == config.tabs, "Tabs should match")
        #expect(decodedConfig.quickAccessItems.count == config.quickAccessItems.count, "Items count should match")
        #expect(
            decodedConfig.quickAccessItems[0].id == config.quickAccessItems[0].id,
            "First item ID should match"
        )
        #expect(
            decodedConfig.quickAccessItems[0].serverId == config.quickAccessItems[0].serverId,
            "First item server ID should match"
        )
        #expect(
            decodedConfig.quickAccessItems[0].type == config.quickAccessItems[0].type,
            "First item type should match"
        )
    }

    @Test func testConfigurationExportFormat() throws {
        // Create a test configuration
        let config = CarPlayConfig(
            id: "carplay-config",
            tabs: [.quickAccess, .areas],
            quickAccessItems: [
                .init(
                    id: "script.test",
                    serverId: "test-server",
                    type: .script
                ),
            ]
        )

        // Encode configuration
        let configEncoder = JSONEncoder()
        let configData = try configEncoder.encode(config)

        // Create export container
        let exportContainer = ConfigurationExport(
            version: .v1,
            type: .carPlay,
            data: configData
        )

        // Encode container
        let containerEncoder = JSONEncoder()
        containerEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let containerData = try containerEncoder.encode(exportContainer)

        #expect(containerData.count > 0, "Container data should not be empty")

        // Decode and verify
        let decoder = JSONDecoder()
        let decodedContainer = try decoder.decode(ConfigurationExport.self, from: containerData)

        #expect(decodedContainer.version == .v1, "Version should be v1")
        #expect(decodedContainer.type == .carPlay, "Type should be carPlay")
        #expect(decodedContainer.data.count > 0, "Config data should not be empty")

        // Decode the inner configuration
        let decodedConfig = try decoder.decode(CarPlayConfig.self, from: decodedContainer.data)
        #expect(decodedConfig.id == config.id, "Config ID should match")
        #expect(decodedConfig.tabs == config.tabs, "Tabs should match")
    }

    @Test func testConfigurationTypeFileName() throws {
        let carPlayFileName = ConfigurationType.carPlay.fileName()
        #expect(carPlayFileName == "HomeAssistant-CarPlay-v1.homeassistant", "CarPlay filename should be versioned")

        let watchFileName = ConfigurationType.watch.fileName()
        #expect(watchFileName == "HomeAssistant-Apple Watch-v1.homeassistant", "Watch filename should be versioned")

        let widgetsFileName = ConfigurationType.widgets.fileName()
        #expect(
            widgetsFileName == "HomeAssistant-Widgets-v1.homeassistant",
            "Widgets filename should be versioned"
        )
    }
}
