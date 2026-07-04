@testable import HomeAssistant
@testable import Shared
import Testing

struct AppIconShortcutItemsUpdaterTests {
    @Test func iconSystemImageNameUsesCustomizedIconWhenPresent() {
        let item = MagicItem(
            id: "light.living_room",
            serverId: "server-1",
            type: .entity,
            customization: .init(icon: "sfsymbols:house.fill")
        )

        let iconName = AppIconShortcutItemsUpdater.iconSystemImageName(for: item, provider: TestMagicItemProvider())

        #expect(iconName == "house.fill")
    }

    @Test func iconSystemImageNameUsesProviderInfoWhenNoCustomizedIconExists() {
        let item = MagicItem(
            id: "light.living_room",
            serverId: "server-1",
            type: .entity
        )

        let iconName = AppIconShortcutItemsUpdater.iconSystemImageName(for: item, provider: SystemImageMagicItemProvider())

        #expect(iconName == "lightbulb.fill")
    }

    @Test func iconSystemImageNameReturnsNilForUnsupportedIconSets() {
        let item = MagicItem(
            id: "script.goodnight",
            serverId: "server-1",
            type: .script,
            customization: .init(icon: "mdi:garage")
        )

        let iconName = AppIconShortcutItemsUpdater.iconSystemImageName(for: item, provider: EmptyMagicItemProvider())

        #expect(iconName == nil)
    }
}

private struct TestMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(
            id: item.id,
            name: "Lamp",
            iconName: "mdi:lamp",
            customization: nil
        )
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}

private struct SystemImageMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(
            id: item.id,
            name: "Lamp",
            iconName: "sfsymbols:lightbulb.fill",
            customization: nil
        )
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}

private struct EmptyMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        nil
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
