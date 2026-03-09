@testable import HomeAssistant
@testable import Shared
import Testing

// MARK: - MagicItem.Customization showInSmartStack Tests

@Suite("MagicItem.Customization showInSmartStack")
struct MagicItemCustomizationSmartStackTests {
    @Test("showInSmartStack defaults to false")
    func defaultValue() {
        let customization = MagicItem.Customization()
        #expect(customization.showInSmartStack == false)
    }

    @Test("showInSmartStack can be set to true")
    func setToTrue() {
        let customization = MagicItem.Customization(showInSmartStack: true)
        #expect(customization.showInSmartStack == true)
    }

    @Test("showInSmartStack round-trips through JSON encoding/decoding")
    func jsonRoundTrip() throws {
        let original = MagicItem.Customization(iconColor: "FF0000", requiresConfirmation: true, showInSmartStack: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MagicItem.Customization.self, from: data)
        #expect(decoded.showInSmartStack == true)
        #expect(decoded.iconColor == "FF0000")
        #expect(decoded.requiresConfirmation == true)
    }

    @Test("showInSmartStack false round-trips through JSON")
    func jsonRoundTripFalse() throws {
        let original = MagicItem.Customization(showInSmartStack: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MagicItem.Customization.self, from: data)
        #expect(decoded.showInSmartStack == false)
    }

    @Test("Backward compatibility: decoding JSON without showInSmartStack field")
    func backwardCompatibility() throws {
        // Simulate JSON from before showInSmartStack was added
        let json = """
        {"requiresConfirmation": false}
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(MagicItem.Customization.self, from: data)
        #expect(decoded.showInSmartStack == nil, "Missing field should decode as nil")
    }

    @Test("Customization equality includes showInSmartStack")
    func equality() {
        let a = MagicItem.Customization(showInSmartStack: true)
        let b = MagicItem.Customization(showInSmartStack: false)
        let c = MagicItem.Customization(showInSmartStack: true)
        #expect(a != b, "Different showInSmartStack values should not be equal")
        #expect(a == c, "Same showInSmartStack values should be equal")
    }
}

// MARK: - WatchConfig.allSmartStackItems() Tests

@Suite("WatchConfig allSmartStackItems")
struct WatchConfigSmartStackTests {
    @Test("Empty items returns empty smart stack")
    func emptyItems() {
        let config = WatchConfig(items: [])
        #expect(config.allSmartStackItems().isEmpty)
    }

    @Test("Items without showInSmartStack flag are excluded")
    func noFlaggedItems() {
        let config = WatchConfig(items: [
            MagicItem(id: "script.one", serverId: "s1", type: .script),
            MagicItem(id: "scene.two", serverId: "s1", type: .scene),
        ])
        #expect(config.allSmartStackItems().isEmpty)
    }

    @Test("Items with showInSmartStack=true are included")
    func flaggedItems() {
        let config = WatchConfig(items: [
            MagicItem(
                id: "script.one",
                serverId: "s1",
                type: .script,
                customization: .init(showInSmartStack: true)
            ),
            MagicItem(
                id: "scene.two",
                serverId: "s1",
                type: .scene,
                customization: .init(showInSmartStack: false)
            ),
        ])
        let result = config.allSmartStackItems()
        #expect(result.count == 1)
        #expect(result[0].id == "script.one")
    }

    @Test("Items inside folders with showInSmartStack=true are included")
    func folderChildrenIncluded() {
        let folderItem = MagicItem(
            id: "folder_1",
            serverId: "",
            type: .folder,
            customization: .init(),
            displayText: "My Folder",
            items: [
                MagicItem(
                    id: "script.inside",
                    serverId: "s1",
                    type: .script,
                    customization: .init(showInSmartStack: true)
                ),
                MagicItem(
                    id: "scene.inside",
                    serverId: "s1",
                    type: .scene,
                    customization: .init(showInSmartStack: false)
                ),
            ]
        )
        let config = WatchConfig(items: [folderItem])
        let result = config.allSmartStackItems()
        #expect(result.count == 1)
        #expect(result[0].id == "script.inside")
    }

    @Test("Mixed root and folder items are all collected")
    func mixedRootAndFolderItems() {
        let folderItem = MagicItem(
            id: "folder_1",
            serverId: "",
            type: .folder,
            customization: .init(),
            displayText: "Folder",
            items: [
                MagicItem(
                    id: "light.folder_light",
                    serverId: "s1",
                    type: .entity,
                    customization: .init(showInSmartStack: true)
                ),
            ]
        )
        let config = WatchConfig(items: [
            MagicItem(
                id: "script.root",
                serverId: "s1",
                type: .script,
                customization: .init(showInSmartStack: true)
            ),
            folderItem,
            MagicItem(
                id: "scene.unflagged",
                serverId: "s1",
                type: .scene,
                customization: .init(showInSmartStack: false)
            ),
        ])
        let result = config.allSmartStackItems()
        #expect(result.count == 2)
        let ids = result.map(\.id)
        #expect(ids.contains("script.root"))
        #expect(ids.contains("light.folder_light"))
    }

    @Test("Multiple flagged items across multiple servers")
    func multipleServers() {
        let config = WatchConfig(items: [
            MagicItem(
                id: "script.a",
                serverId: "server1",
                type: .script,
                customization: .init(showInSmartStack: true)
            ),
            MagicItem(
                id: "script.b",
                serverId: "server2",
                type: .script,
                customization: .init(showInSmartStack: true)
            ),
        ])
        let result = config.allSmartStackItems()
        #expect(result.count == 2)
        #expect(Set(result.map(\.serverId)) == Set(["server1", "server2"]))
    }
}

// MARK: - WatchConfig smartStackItems(for domain:) Tests

@Suite("WatchConfig smartStackItems domain filtering")
struct WatchConfigSmartStackDomainTests {
    private func configWithVariousDomains() -> WatchConfig {
        WatchConfig(items: [
            MagicItem(
                id: "script.one",
                serverId: "s1",
                type: .script,
                customization: .init(showInSmartStack: true)
            ),
            MagicItem(
                id: "scene.one",
                serverId: "s1",
                type: .scene,
                customization: .init(showInSmartStack: true)
            ),
            MagicItem(
                id: "light.living_room",
                serverId: "s1",
                type: .entity,
                customization: .init(showInSmartStack: true)
            ),
            MagicItem(
                id: "switch.garage",
                serverId: "s1",
                type: .entity,
                customization: .init(showInSmartStack: true)
            ),
            MagicItem(
                id: "input_boolean.alarm",
                serverId: "s1",
                type: .entity,
                customization: .init(showInSmartStack: true)
            ),
            MagicItem(
                id: "script.unflagged",
                serverId: "s1",
                type: .script,
                customization: .init(showInSmartStack: false)
            ),
        ])
    }

    @Test("Filter by script domain")
    func filterByScript() {
        let config = configWithVariousDomains()
        let result = config.allSmartStackItems().filter { $0.domain == .script }
        #expect(result.count == 1)
        #expect(result[0].id == "script.one")
    }

    @Test("Filter by scene domain")
    func filterByScene() {
        let config = configWithVariousDomains()
        let result = config.allSmartStackItems().filter { $0.domain == .scene }
        #expect(result.count == 1)
        #expect(result[0].id == "scene.one")
    }

    @Test("Filter by light domain")
    func filterByLight() {
        let config = configWithVariousDomains()
        let result = config.allSmartStackItems().filter { $0.domain == .light }
        #expect(result.count == 1)
        #expect(result[0].id == "light.living_room")
    }

    @Test("Filter by switch domain")
    func filterBySwitch() {
        let config = configWithVariousDomains()
        let result = config.allSmartStackItems().filter { $0.domain == .switch }
        #expect(result.count == 1)
        #expect(result[0].id == "switch.garage")
    }

    @Test("Filter by inputBoolean domain")
    func filterByInputBoolean() {
        let config = configWithVariousDomains()
        let result = config.allSmartStackItems().filter { $0.domain == .inputBoolean }
        #expect(result.count == 1)
        #expect(result[0].id == "input_boolean.alarm")
    }

    @Test("Filter returns empty when no items match domain")
    func filterNoMatch() {
        let config = WatchConfig(items: [
            MagicItem(
                id: "script.only",
                serverId: "s1",
                type: .script,
                customization: .init(showInSmartStack: true)
            ),
        ])
        let result = config.allSmartStackItems().filter { $0.domain == .light }
        #expect(result.isEmpty)
    }
}

// MARK: - MagicItem.serverUniqueId Tests

@Suite("MagicItem serverUniqueId")
struct MagicItemServerUniqueIdTests {
    @Test("serverUniqueId matches HAAppEntity ID format")
    func formatMatchesEntityId() {
        let item = MagicItem(id: "script.open_gate", serverId: "EB1364", type: .script)
        #expect(item.serverUniqueId == "EB1364-script.open_gate")
    }

    @Test("serverUniqueId works for light entities")
    func lightEntityId() {
        let item = MagicItem(id: "light.living_room", serverId: "server1", type: .entity)
        #expect(item.serverUniqueId == "server1-light.living_room")
    }

    @Test("serverUniqueId works for switch entities")
    func switchEntityId() {
        let item = MagicItem(id: "switch.garage", serverId: "server1", type: .entity)
        #expect(item.serverUniqueId == "server1-switch.garage")
    }
}

// MARK: - MagicItem.domain Tests

@Suite("MagicItem domain parsing")
struct MagicItemDomainTests {
    @Test("Domain parses correctly for scripts")
    func scriptDomain() {
        let item = MagicItem(id: "script.test", serverId: "s1", type: .script)
        #expect(item.domain == .script)
    }

    @Test("Domain parses correctly for scenes")
    func sceneDomain() {
        let item = MagicItem(id: "scene.test", serverId: "s1", type: .scene)
        #expect(item.domain == .scene)
    }

    @Test("Domain parses correctly for lights")
    func lightDomain() {
        let item = MagicItem(id: "light.test", serverId: "s1", type: .entity)
        #expect(item.domain == .light)
    }

    @Test("Domain parses correctly for switches")
    func switchDomain() {
        let item = MagicItem(id: "switch.test", serverId: "s1", type: .entity)
        #expect(item.domain == .switch)
    }

    @Test("Domain parses correctly for input_boolean")
    func inputBooleanDomain() {
        let item = MagicItem(id: "input_boolean.test", serverId: "s1", type: .entity)
        #expect(item.domain == .inputBoolean)
    }
}

// MARK: - WatchSupportedDomains Tests

@Suite("WatchSupportedDomains")
struct WatchSupportedDomainsTests {
    @Test("Includes script domain")
    func includesScript() {
        #expect(WatchSupportedDomains.all.contains(.script))
    }

    @Test("Includes scene domain")
    func includesScene() {
        #expect(WatchSupportedDomains.all.contains(.scene))
    }

    @Test("Includes light domain")
    func includesLight() {
        #expect(WatchSupportedDomains.all.contains(.light))
    }

    @Test("Includes switch domain")
    func includesSwitch() {
        #expect(WatchSupportedDomains.all.contains(.switch))
    }

    @Test("Includes inputBoolean domain")
    func includesInputBoolean() {
        #expect(WatchSupportedDomains.all.contains(.inputBoolean))
    }

    @Test("Contains exactly 5 domains")
    func exactCount() {
        #expect(WatchSupportedDomains.all.count == 5)
    }
}
