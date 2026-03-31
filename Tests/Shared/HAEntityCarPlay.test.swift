import HAKit
@testable import Shared
import Testing
import UIKit

struct HAEntityCarPlayTests {
    @Test("Given an entity without a custom icon when requesting a CarPlay icon then it uses the domain/state icon")
    func usesDomainAndStateBasedIconWhenNoCustomIconExists() throws {
        let entity = try HAEntity(
            entityId: "light.kitchen",
            state: Domain.State.off.rawValue,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "friendly_name": "Kitchen light",
            ],
            context: .init(id: "context", userId: "user", parentId: nil)
        )

        let actualData = try #require(entity.getIcon()?.pngData())
        let expectedData = try #require(
            MaterialDesignIcons.lightbulbIcon
                .carPlayIcon(color: .lightGray)
                .pngData()
        )

        #expect(actualData == expectedData)
    }

    @Test(
        "Given an entity with a custom icon when requesting a CarPlay icon then it preserves that icon before falling back"
    )
    func usesCustomAttributeIconBeforeFallbacks() throws {
        let entity = try HAEntity(
            entityId: "sensor.temperature",
            state: "23",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "friendly_name": "Temperature",
                "icon": "mdi:thermometer",
            ],
            context: .init(id: "context", userId: "user", parentId: nil)
        )

        let actualData = try #require(entity.getIcon()?.pngData())
        let expectedData = try #require(
            MaterialDesignIcons.thermometerIcon
                .carPlayIcon()
                .pngData()
        )

        #expect(actualData == expectedData)
    }
}
