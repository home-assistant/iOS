@testable import HomeAssistant
@testable import Shared
import XCTest

final class AppIconShortcutItemsUpdaterTests: XCTestCase {
    func testEntityUsesMaterialDesignIconFromInfo() {
        let item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        let provider = FakeMagicItemProvider(info: .init(
            id: "1-light.kitchen",
            name: "Kitchen",
            iconName: "mdi:lightbulb"
        ))

        let icon = AppIconShortcutItemsUpdater.materialDesignIcon(for: item, provider: provider)

        XCTAssertEqual(icon, MaterialDesignIcons.lightbulbIcon)
        XCTAssertEqual(icon.similarSFSymbol, MaterialDesignIcons.lightbulbIcon.similarSFSymbol)
        XCTAssertNotEqual(icon.similarSFSymbol.rawValue, "lightbulbIcon")
    }

    func testCustomizationIconWinsOverEntityIcon() {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            customization: .init(icon: MaterialDesignIcons.lockIcon.name)
        )
        let provider = FakeMagicItemProvider(info: .init(
            id: "1-light.kitchen",
            name: "Kitchen",
            iconName: "mdi:lightbulb"
        ))

        let icon = AppIconShortcutItemsUpdater.materialDesignIcon(for: item, provider: provider)

        XCTAssertEqual(icon, MaterialDesignIcons.lockIcon)
    }

    func testMissingInfoFallsBackToTypeMaterialDesignIcon() {
        let item = MagicItem(id: "script.open_gate", serverId: "1", type: .script)
        let provider = FakeMagicItemProvider(info: nil)

        let icon = AppIconShortcutItemsUpdater.materialDesignIcon(for: item, provider: provider)

        XCTAssertEqual(icon, MaterialDesignIcons.scriptIcon)
        XCTAssertEqual(icon, AppIconShortcutItemsUpdater.fallbackIcon(for: .script))
    }

    func testFallbackIconsAreMaterialDesignIconsNotStringSFSymbols() {
        XCTAssertEqual(AppIconShortcutItemsUpdater.fallbackIcon(for: .scene), .paletteIcon)
        XCTAssertEqual(AppIconShortcutItemsUpdater.fallbackIcon(for: .entity), .dotsGridIcon)
        XCTAssertEqual(AppIconShortcutItemsUpdater.fallbackIcon(for: .folder), .folderIcon)
        XCTAssertEqual(AppIconShortcutItemsUpdater.fallbackIcon(for: .area), .textureBoxIcon)
        XCTAssertEqual(AppIconShortcutItemsUpdater.fallbackIcon(for: .assistPipeline), .microphoneIcon)
        XCTAssertEqual(AppIconShortcutItemsUpdater.fallbackIcon(for: .assistPrompt), .messageProcessingOutlineIcon)
        XCTAssertEqual(AppIconShortcutItemsUpdater.fallbackIcon(for: .complication), .watchIcon)
    }

    func testShortcutSymbolIsMappedFromMaterialDesignIcons() {
        let item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        let provider = FakeMagicItemProvider(info: .init(
            id: "1-light.kitchen",
            name: "Kitchen",
            iconName: "mdi:home"
        ))

        let icon = AppIconShortcutItemsUpdater.materialDesignIcon(for: item, provider: provider)

        XCTAssertEqual(icon, MaterialDesignIcons.homeIcon)
        XCTAssertEqual(icon.similarSFSymbol.rawValue, "house")
    }
}

private final class FakeMagicItemProvider: MagicItemProviderProtocol {
    let info: MagicItem.Info?

    init(info: MagicItem.Info?) {
        self.info = info
    }

    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        info
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
