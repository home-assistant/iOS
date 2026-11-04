import CarPlay
import HAKit
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Covers which color a Quick Access entity row paints its icon with: the one the driver picked in
/// the CarPlay configuration when there is one, and the entity's live state color otherwise.
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

    /// The regression: an inactive entity used to drop the picked color for the neutral "off" grey,
    /// so a configured row turned grey as soon as its state arrived.
    func testAnInactiveEntityKeepsTheConfiguredIconColor() throws {
        let offEntity = try entity(state: "off")
        let item = magicItem(customization: .init(iconColor: "#FF0000", iconColorIsCustomized: true))

        let color = iconColor(entity: offEntity, item: item)

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

    /// The app's tint was `#00AEF8` until September 2025, and the customization screen seeded items
    /// with it back then. An off light carrying it reads as off, not as a light that is on.
    func testAColorSeededWithTheFormerTintIsNotTreatedAsConfigured() throws {
        let offEntity = try entity(state: "off")
        let item = magicItem(customization: .init(iconColor: "00AEF8"))

        let color = iconColor(entity: offEntity, item: item)

        try assertSameColor(color, offEntity.stateIconColor())
    }

    /// Rows outside Quick Access carry no magic item at all, so they stay on the state color.
    func testAnEntityRowWithoutAMagicItemUsesTheStateColor() throws {
        let onEntity = try entity(state: "on")

        let color = iconColor(entity: onEntity, item: nil)

        try assertSameColor(color, onEntity.stateIconColor())
    }

    // MARK: - Detail text and the executing subtitle

    private func spinRunLoop(until condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "condition not met within 10 s", file: file, line: line)
    }

    func testTheAreaFollowsTheStateOrStandsAloneForStatelessDomains() throws {
        let light = try CarPlayEntityListItem(serverId: serverId, entity: entity(state: "on"), area: "Kitchen")
        XCTAssertEqual(light.template.detailText?.hasSuffix("Kitchen"), true)
        XCTAssertNotEqual(light.template.detailText, "Kitchen")

        let script = try CarPlayEntityListItem(
            serverId: serverId,
            entity: entity(id: "script.morning", state: "off"),
            area: "Kitchen"
        )
        XCTAssertEqual(script.template.detailText, "Kitchen")
    }

    /// An entity outside the known domains shows its raw state, with the unit when it has one.
    func testAnUnknownDomainShowsItsStateAndUnit() throws {
        let plain = try CarPlayEntityListItem(serverId: serverId, entity: entity(id: "mystery.thing", state: "idle"))
        XCTAssertEqual(plain.template.detailText?.isEmpty, false)

        let measured = try HAEntity(
            entityId: "mystery.level",
            state: "12",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["unit_of_measurement": "cm"],
            context: .init(id: "", userId: "", parentId: "")
        )
        let item = CarPlayEntityListItem(serverId: serverId, entity: measured)
        XCTAssertEqual(item.template.detailText?.hasSuffix(" cm"), true)
    }

    /// A state update arriving mid-action keeps "Executing…" up until its minimum duration has
    /// passed, then the row reports its state again and tells the list to redraw.
    func testTheExecutingSubtitleOutlivesAnEarlyStateUpdate() throws {
        let item = try CarPlayEntityListItem(serverId: serverId, entity: entity(state: "off"))
        var deferredUpdates = 0
        item.onDeferredPresentationUpdate = { deferredUpdates += 1 }

        item.setExecutingState(true)
        try item.update(serverId: serverId, entity: entity(state: "on"))
        XCTAssertEqual(item.template.detailText, CarPlayEntityListItem.executingSubtitle)

        spinRunLoop { deferredUpdates == 1 }
        XCTAssertNotEqual(item.template.detailText, CarPlayEntityListItem.executingSubtitle)
    }

    /// Once the minimum duration has already passed when the action finishes, the subtitle clears
    /// at once.
    func testAnActionFinishingAfterTheMinimumDurationClearsAtOnce() throws {
        let item = try CarPlayEntityListItem(serverId: serverId, entity: entity(state: "off"))
        var deferredUpdates = 0
        item.onDeferredPresentationUpdate = { deferredUpdates += 1 }
        item.setExecutingState(true)
        let started = Date()

        // Let the minimum executing duration elapse; nothing asynchronous is awaited here.
        spinRunLoop { Date().timeIntervalSince(started) > 1.6 }
        item.setExecutingState(false)

        XCTAssertEqual(deferredUpdates, 1)
        XCTAssertNotEqual(item.template.detailText, CarPlayEntityListItem.executingSubtitle)
    }
}
