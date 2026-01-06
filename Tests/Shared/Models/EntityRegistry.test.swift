import Foundation
@testable import Shared
import Testing

@Suite("Entity Registry Tests")
struct EntityRegistryTests {
    @Test("Decode entity registry entry from JSON file")
    func decodeEntityRegistryFromFile() async throws {
        let bundle = Bundle(for: ClientEventTests.self)

        guard let url = bundle.url(forResource: "entityregistry", withExtension: "json") else {
            Issue.record("Could not find entityregistry.json in any bundle. Make sure it's added to the test target.")
            return
        }

        let jsonData = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let entries = try decoder.decode([EntityRegistryEntry].self, from: jsonData)

        #expect(entries.count == 4913, "Expected 4913 entries, found \(entries.count)")

        // Validate the first entry
        let firstEntry = try #require(entries.first, "Expected at least one entry in the registry")

        #expect(firstEntry.areaId == nil)
        #expect(firstEntry.configEntryId == "27f48e744a782b41f674111ff39e84e5")
        #expect(firstEntry.deviceId == "45bb06f969341e46077016df63f2054f")
        #expect(firstEntry.disabledBy == nil)
        #expect(firstEntry.entityCategory == "config")
        #expect(firstEntry.entityId == "update.home_assistant_supervisor_update")
        #expect(firstEntry.hasEntityName == true)
        #expect(firstEntry.hiddenBy == nil)
        #expect(firstEntry.icon == nil)
        #expect(firstEntry.labels == [])
        #expect(firstEntry.name == nil)
        #expect(firstEntry.originalName == "Update")
        #expect(firstEntry.platform == "hassio")
        #expect(firstEntry.translationKey == "update")
        #expect(firstEntry.uniqueId == "home_assistant_supervisor_version_latest")

        // Validate the options dictionary structure
        let options = try #require(firstEntry.options, "Expected options to be present")
        #expect(options.keys.contains("conversation"), "Expected 'conversation' key in options")

        if let conversationOptions = options["conversation"] {
            #expect(
                conversationOptions.keys.contains("should_expose"),
                "Expected 'should_expose' key in conversation options"
            )
        }

        // Validate computed properties
        #expect(firstEntry.displayName == "Update")
        #expect(firstEntry.displayIcon == nil)
        #expect(firstEntry.isDisabled == false)
        #expect(firstEntry.isHidden == false)
        #expect(firstEntry.isConfiguration == true)
        #expect(firstEntry.isDiagnostic == false)
    }
}
