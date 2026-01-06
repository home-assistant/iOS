import Foundation
@testable import Shared
import Testing

@Suite("Device Registry Tests")
struct DeviceRegistryTests {
    @Test("Decode device registry entry from JSON file")
    func decodeDeviceRegistryFromFile() async throws {
        let bundle = Bundle(for: ClientEventTests.self)

        guard let url = bundle.url(forResource: "deviceregistry", withExtension: "json") else {
            Issue.record("Could not find deviceregistry.json in any bundle. Make sure it's added to the test target.")
            return
        }

        let jsonData = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let entries = try decoder.decode([DeviceRegistryEntry].self, from: jsonData)

        #expect(entries.count > 0, "Expected at least one device entry")

        // Validate the first entry
        let firstEntry = try #require(entries.first, "Expected at least one entry in the registry")

        // Validate specific fields from the first entry
        #expect(firstEntry.areaId == nil)
        #expect(firstEntry.configurationURL == nil)
        #expect(firstEntry.configEntries == ["27f48e744a782b41f674111ff39e84e5"])

        // Validate config_entries_subentries structure
        #expect(firstEntry.configEntriesSubentries!.keys.contains("27f48e744a782b41f674111ff39e84e5"))
        if let subentries = firstEntry.configEntriesSubentries!["27f48e744a782b41f674111ff39e84e5"] {
            #expect(subentries == [nil])
        }

        #expect(firstEntry.connections!.isEmpty)
        #expect(firstEntry.createdAt == 0.0)
        #expect(firstEntry.disabledBy == nil)
        #expect(firstEntry.entryType == "service")
        #expect(firstEntry.hwVersion == nil)
        #expect(firstEntry.id == "0c1df9819f004ccbc14d8d7e0a7e1b02")
        #expect(firstEntry.identifiers == [["hassio", "core"]])
        #expect(firstEntry.labels == [])
        #expect(firstEntry.manufacturer == "Home Assistant")
        #expect(firstEntry.model == "Home Assistant Core")
        #expect(firstEntry.modelID == nil)
        #expect(firstEntry.modifiedAt == 1_767_135_352.243404)
        #expect(firstEntry.nameByUser == nil)
        #expect(firstEntry.name == "Home Assistant Core")
        #expect(firstEntry.primaryConfigEntry == "27f48e744a782b41f674111ff39e84e5")
        #expect(firstEntry.serialNumber == nil)
        #expect(firstEntry.swVersion == "2025.12.5")
        #expect(firstEntry.viaDeviceID == nil)

        // Validate computed properties
        #expect(firstEntry.displayName == "Home Assistant Core")
        #expect(firstEntry.isDisabled == false)
    }
}
