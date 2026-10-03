import CarPlay
import HAKit
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Covers which color a Quick Access entity row paints its icon with: the one the driver picked in
/// the CarPlay configuration while the entity is active, and the entity's live state color otherwise.
final class CarPlayEntityListItemTests: XCTestCase {
    private let serverId = "server-1"

    private func entity(id: String = "light.kitchen", state: String) throws -> HAEntity {
        try HAEntity(
            entityId: id,
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: "", parentId: "")
        )
    }

    private func magicItem(id: String = "light.kitchen", customization: MagicItem.Customization?) -> MagicItem {
        MagicItem(id: id, serverId: serverId, type: .entity, customization: customization)
    }

    private func info(for item: MagicItem) -> MagicItem.Info {
        .init(id: item.id, name: item.id, iconName: "", customization: item.customization)
    }

    private func iconColor(entity: HAEntity, item: MagicItem?) -> UIColor? {
        CarPlayEntityListItem(
            serverId: serverId,
            entity: entity,
            magicItem: item,
            magicItemInfo: item.map { info(for: $0) }
        ).currentDisplayContent().iconColor
    }

    private func components(of color: UIColor) -> [CGFloat] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }

    /// `UIColor` equality depends on the color space, so compare what actually gets drawn.
    private func assertSameColor(
        _ lhs: UIColor?,
        _ rhs: UIColor?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let lhs = try components(of: XCTUnwrap(lhs, file: file, line: line))
        let rhs = try components(of: XCTUnwrap(rhs, file: file, line: line))

        for (lhs, rhs) in zip(lhs, rhs) {
            XCTAssertEqual(lhs, rhs, accuracy: 0.01, file: file, line: line)
        }
    }

    /// A light that is off reads as off, as in the frontend, rather than looking on in its picked color.
    func testAnInactiveEntityDropsTheConfiguredIconColor() throws {
        let offEntity = try entity(state: "off")
        let item = magicItem(customization: .init(iconColor: "#FF0000", iconColorIsCustomized: true))

        let color = iconColor(entity: offEntity, item: item)

        try assertSameColor(color, offEntity.stateIconColor())
    }

    /// A script that isn't running reports "off", which says nothing about whether anything is on, so
    /// its row keeps the picked color instead of turning grey as soon as its state arrives.
    func testAnIdleScriptKeepsTheConfiguredIconColor() throws {
        let idleScript = try entity(id: "script.good_night", state: "off")
        let item = magicItem(
            id: "script.good_night",
            customization: .init(iconColor: "#FF0000", iconColorIsCustomized: true)
        )

        let color = iconColor(entity: idleScript, item: item)

        try assertSameColor(color, UIColor(hex: "#FF0000"))
    }

    func testAnActiveEntityKeepsTheConfiguredIconColor() throws {
        let onEntity = try entity(state: "on")
        let item = magicItem(customization: .init(iconColor: "#FF0000", iconColorIsCustomized: true))

        let color = iconColor(entity: onEntity, item: item)

        try assertSameColor(color, UIColor(hex: "#FF0000"))
    }

    func testAnItemWithoutAConfiguredColorUsesTheStateColor() throws {
        let offEntity = try entity(state: "off")
        let item = magicItem(customization: .init())

        let color = iconColor(entity: offEntity, item: item)

        try assertSameColor(color, offEntity.stateIconColor())
    }

    /// The customization screen seeds its picker with the app's tint, so an item carrying that color
    /// without ``MagicItem/Customization/iconColorIsCustomized`` never had a color picked for it.
    func testASeededColorIsNotTreatedAsConfigured() throws {
        let offEntity = try entity(state: "off")
        let item = magicItem(customization: .init(iconColor: MagicItem.defaultIconColorHex))

        let color = iconColor(entity: offEntity, item: item)

        try assertSameColor(color, offEntity.stateIconColor())
    }

    /// Rows outside Quick Access carry no magic item at all, so they stay on the state color.
    func testAnEntityRowWithoutAMagicItemUsesTheStateColor() throws {
        let onEntity = try entity(state: "on")

        let color = iconColor(entity: onEntity, item: nil)

        try assertSameColor(color, onEntity.stateIconColor())
    }
}
