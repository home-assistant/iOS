@testable import HomeAssistant
import XCTest

final class NativeModalHeaderTests: XCTestCase {
    /// The bar shows exactly what the frontend described, in the frontend's order.
    func testParsesTheFrontendsHeader() throws {
        let header = try XCTUnwrap(NativeModalHeader(payload: [
            "title": "Kitchen ceiling",
            "subtitle": "Kitchen ▸ Hue bridge",
            "navigation": "close",
            "navigation_label": "Close",
            "menu_label": "Menu",
            "actions": [
                ["id": "history", "label": "History", "icon": "mdi:chart-box-outline"],
                ["id": "settings", "label": "Settings", "icon": "mdi:cog-outline"],
            ],
            "menu": [
                ["id": "add_to", "label": "Add to", "icon": "mdi:plus-box-multiple-outline", "divider_after": true],
                ["id": "copy_favorites", "label": "Copy favorites", "icon": "mdi:content-duplicate", "disabled": true],
                ["id": "details", "label": "Details", "icon": "mdi:information-outline"],
            ],
        ]))

        XCTAssertEqual(header.title, "Kitchen ceiling")
        XCTAssertEqual(header.subtitle, "Kitchen ▸ Hue bridge")
        XCTAssertEqual(header.navigation, .close)
        XCTAssertEqual(header.navigationLabel, "Close")
        XCTAssertEqual(header.menuLabel, "Menu")
        XCTAssertEqual(header.actions.map(\.id), ["history", "settings"])
        XCTAssertEqual(header.actions.first?.label, "History")
        XCTAssertEqual(header.actions.first?.icon, "mdi:chart-box-outline")
        XCTAssertEqual(header.menu.map(\.id), ["add_to", "copy_favorites", "details"])
        XCTAssertTrue(header.menu[0].hasDividerAfter)
        XCTAssertFalse(header.menu[0].isDisabled)
        XCTAssertTrue(header.menu[1].isDisabled)
        XCTAssertFalse(header.menu[1].hasDividerAfter)
    }

    /// A secondary view has a back button and nothing else; missing lists mean empty ones.
    func testABackHeaderWithoutItems() throws {
        let header = try XCTUnwrap(NativeModalHeader(payload: [
            "title": "History",
            "navigation": "back",
            "navigation_label": "Back to info",
        ]))

        XCTAssertEqual(header.navigation, .back)
        XCTAssertNil(header.subtitle)
        XCTAssertEqual(header.actions, [])
        XCTAssertEqual(header.menu, [])
    }

    /// An item the app cannot draw (no id, label or icon) is left out rather than failing the header.
    func testSkipsMalformedItemsAndUnknownNavigation() throws {
        let header = try XCTUnwrap(NativeModalHeader(payload: [
            "title": "Kitchen ceiling",
            "navigation": "sideways",
            "actions": [
                ["id": "history", "label": "History"],
                ["id": "settings", "label": "Settings", "icon": "mdi:cog-outline"],
            ],
        ]))

        XCTAssertEqual(header.navigation, .close)
        XCTAssertEqual(header.actions.map(\.id), ["settings"])
    }

    /// A bar with no title has nothing to draw; everything else the frontend may leave out.
    func testAHeaderNeedsATitle() {
        XCTAssertNil(NativeModalHeader(payload: nil))
        XCTAssertNil(NativeModalHeader(payload: ["subtitle": "Kitchen"]))
        XCTAssertEqual(NativeModalHeader(payload: ["title": "Kitchen ceiling"])?.title, "Kitchen ceiling")
    }
}
