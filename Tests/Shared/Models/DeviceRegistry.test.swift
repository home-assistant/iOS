import Foundation
import HAKit
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

    @Test("Entry with a non-string identifier tuple still decodes")
    func decodeEntryWithNonStringIdentifier() throws {
        let data = HAData(value: [
            "id": "abc123",
            "name": "Weird Device",
            "identifiers": [["mqtt", 42]],
            "connections": [["mac", 99]],
        ])

        let entry = try DeviceRegistryEntry(data: data)

        #expect(entry.id == "abc123")
        #expect(entry.name == "Weird Device")
        #expect(entry.identifiers == nil)
        #expect(entry.connections == nil)
    }

    @Test("A stripped child entry decodes and keeps its parent")
    func decodeChildEntry() throws {
        let data = HAData(value: [
            "id": "outlet-2",
            "name": "Outlet 2",
            "config_entry_id": "entry-1",
            "labels": [],
            "parent_device_id": "power-strip",
        ])

        let entry = try DeviceRegistryEntry(data: data)

        #expect(entry.id == "outlet-2")
        #expect(entry.parentDeviceId == "power-strip")
        #expect(entry.configEntryId == "entry-1")
        #expect(entry.isChildDevice)
        #expect(entry.connections == nil)
        #expect(entry.configEntries == nil)
        #expect(entry.manufacturer == nil)
    }

    @Test("Child devices inherit their parent's hardware and their own config entry")
    func resolveChildDevices() throws {
        let parent = DeviceRegistryEntry(
            areaId: "kitchen",
            configurationURL: "http://strip.local",
            configEntries: ["entry-1"],
            configEntriesSubentries: ["entry-1": [nil]],
            connections: [["mac", "aa:bb"]],
            createdAt: 0,
            disabledBy: nil,
            entryType: nil,
            hwVersion: "1.0",
            id: "power-strip",
            identifiers: [["demo", "strip"]],
            labels: [],
            manufacturer: "Acme",
            model: "Strip 4000",
            modelID: "S4000",
            modifiedAt: 0,
            nameByUser: nil,
            name: "Power strip",
            primaryConfigEntry: "entry-1",
            serialNumber: "SN-1",
            swVersion: "2.0",
            viaDeviceID: "hub"
        )
        let child = DeviceRegistryEntry(
            areaId: nil,
            configurationURL: nil,
            configEntries: nil,
            configEntriesSubentries: nil,
            configEntryId: "entry-1",
            configSubentryId: "sub-1",
            connections: nil,
            createdAt: 0,
            disabledBy: "device",
            entryType: nil,
            hwVersion: nil,
            id: "outlet-2",
            identifiers: [["demo", "outlet-2"]],
            labels: [],
            manufacturer: nil,
            model: nil,
            modelID: nil,
            modifiedAt: 0,
            nameByUser: nil,
            name: "Outlet 2",
            parentDeviceId: "power-strip",
            primaryConfigEntry: nil,
            serialNumber: nil,
            swVersion: nil,
            viaDeviceID: nil
        )

        let resolved = AppDeviceRegistry.resolvingChildDevices([parent, child], serverId: "1")
        let resolvedChild = try #require(resolved.first { $0.deviceId == "outlet-2" })

        #expect(resolvedChild.manufacturer == "Acme")
        #expect(resolvedChild.model == "Strip 4000")
        #expect(resolvedChild.modelID == "S4000")
        #expect(resolvedChild.hwVersion == "1.0")
        #expect(resolvedChild.swVersion == "2.0")
        #expect(resolvedChild.serialNumber == "SN-1")
        #expect(resolvedChild.configurationURL == "http://strip.local")
        #expect(resolvedChild.configEntries == ["entry-1"])
        #expect(resolvedChild.configEntriesSubentries == ["entry-1": ["sub-1"]])
        #expect(resolvedChild.primaryConfigEntry == "entry-1")
        #expect(resolvedChild.connections == nil)
        #expect(resolvedChild.viaDeviceID == nil)
        #expect(resolvedChild.parentDeviceId == "power-strip")
        #expect(resolvedChild.isChildDevice)
        #expect(resolvedChild.isDisabled)
        let resolvedParent = try #require(resolved.first { $0.deviceId == "power-strip" })
        #expect(resolvedParent.viaDeviceID == "hub")
        #expect(!resolvedParent.isChildDevice)
    }

    @Test("A child whose parent is missing keeps what it carries itself")
    func resolveChildWithoutParent() throws {
        let child = DeviceRegistryEntry(
            areaId: "kitchen",
            configurationURL: nil,
            configEntries: nil,
            configEntriesSubentries: nil,
            configEntryId: "entry-1",
            configSubentryId: nil,
            connections: nil,
            createdAt: 0,
            disabledBy: nil,
            entryType: nil,
            hwVersion: nil,
            id: "outlet-2",
            identifiers: nil,
            labels: [],
            manufacturer: nil,
            model: nil,
            modelID: nil,
            modifiedAt: 0,
            nameByUser: nil,
            name: "Outlet 2",
            parentDeviceId: "power-strip",
            primaryConfigEntry: nil,
            serialNumber: nil,
            swVersion: nil,
            viaDeviceID: nil
        )

        let resolved = AppDeviceRegistry.resolvingChildDevices([child], serverId: "1")

        #expect(resolved.count == 1)
        #expect(resolved.first?.displayName == "Outlet 2")
        #expect(resolved.first?.areaId == "kitchen")
        #expect(resolved.first?.manufacturer == nil)
    }

    @Test("Effective area falls back to the parent's, and only when the child has none")
    func effectiveAreaId() {
        let parent = makeDevice(areaId: "kitchen", deviceId: "power-strip")
        let inheriting = makeDevice(areaId: nil, deviceId: "outlet-1", parentDeviceId: "power-strip")
        let overriding = makeDevice(areaId: "garage", deviceId: "outlet-2", parentDeviceId: "power-strip")
        let orphan = makeDevice(areaId: nil, deviceId: "outlet-3", parentDeviceId: "gone")
        let devicesById = Dictionary(
            [parent, inheriting, overriding, orphan].map { ($0.deviceId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        #expect(parent.effectiveAreaId(in: devicesById) == "kitchen")
        #expect(inheriting.effectiveAreaId(in: devicesById) == "kitchen")
        #expect(overriding.effectiveAreaId(in: devicesById) == "garage")
        #expect(orphan.effectiveAreaId(in: devicesById) == nil)
    }

    @Test("A single malformed entry does not fail the whole registry array")
    func decodeArrayWithOneMalformedEntry() throws {
        let data = HAData(value: [
            [
                "id": "good",
                "name": "Good Device",
                "identifiers": [["hassio", "core"]],
            ],
            [
                "id": "bad",
                "name": "Bad Device",
                "identifiers": [["mqtt", 42]],
            ],
        ])

        let entries = try [DeviceRegistryEntry](data: data)

        #expect(entries.count == 2)
        #expect(entries.first?.identifiers == [["hassio", "core"]])
        #expect(entries.last?.identifiers == nil)
    }

    private func makeDevice(
        areaId: String?,
        deviceId: String,
        parentDeviceId: String? = nil
    ) -> AppDeviceRegistry {
        AppDeviceRegistry(
            serverId: "1",
            deviceId: deviceId,
            areaId: areaId,
            configurationURL: nil,
            configEntries: nil,
            configEntriesSubentries: nil,
            connections: nil,
            createdAt: nil,
            disabledBy: nil,
            entryType: nil,
            hwVersion: nil,
            identifiers: nil,
            labels: nil,
            manufacturer: nil,
            model: nil,
            modelID: nil,
            modifiedAt: nil,
            nameByUser: nil,
            name: deviceId,
            parentDeviceId: parentDeviceId,
            primaryConfigEntry: nil,
            serialNumber: nil,
            swVersion: nil,
            viaDeviceID: nil
        )
    }
}
