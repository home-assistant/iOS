@testable import HomeAssistant
@testable import Shared
import Testing

struct AppIconShortcutItemsUpdaterTests {
    @Test func iconNameUsesCustomizedIconWhenPresent() {
        let item = MagicItem(
            id: "light.living_room",
            serverId: "server-1",
            type: .entity,
            customization: .init(icon: "mdi:garage")
        )

        let iconName = AppIconShortcutItemsUpdater.iconName(for: item, provider: TestMagicItemProvider())

        #expect(iconName == "garage")
    }

    @Test func iconNameUsesProviderInfoWhenNoCustomizedIconExists() {
        let item = MagicItem(
            id: "light.living_room",
            serverId: "server-1",
            type: .entity
        )

        let iconName = AppIconShortcutItemsUpdater.iconName(for: item, provider: TestMagicItemProvider())

        #expect(iconName == "lamp")
    }

    @Test func iconNameFallsBackToTypeDefaultWhenProviderHasNoInfo() {
        let item = MagicItem(
            id: "script.goodnight",
            serverId: "server-1",
            type: .script
        )

        let iconName = AppIconShortcutItemsUpdater.iconName(for: item, provider: EmptyMagicItemProvider())

        #expect(iconName == MaterialDesignIcons.scriptTextOutlineIcon.name)
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
