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

    @Test func testCarPlayConfigFileExtension() throws {
        let fileName = "CarPlay.homeassistant"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        #expect(fileURL.pathExtension == "homeassistant", "File extension should be homeassistant")
        #expect(fileURL.lastPathComponent == fileName, "File name should match")
    }
}
