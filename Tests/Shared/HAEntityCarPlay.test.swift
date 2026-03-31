import HAKit
@testable import Shared
import Testing
import UIKit

@MainActor
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
                .carPlayIcon(color: UIColor(.secondary))
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
                .carPlayIcon(color: UIColor(.secondary))
                .pngData()
        )

        #expect(actualData == expectedData)
    }

    @Test("Given an active light with server RGB color when requesting a CarPlay icon then it uses that live color")
    func usesServerProvidedRGBColorForActiveLightIcon() throws {
        let entity = try HAEntity(
            entityId: "light.kitchen",
            state: Domain.State.on.rawValue,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "friendly_name": "Kitchen light",
                "color_mode": "rgb",
                "rgb_color": [255, 140, 0],
            ],
            context: .init(id: "context", userId: "user", parentId: nil)
        )

        let actualData = try #require(entity.getIcon()?.pngData())
        let expectedData = try #require(
            MaterialDesignIcons.lightbulbIcon
                .carPlayIcon(color: UIColor(red: 1, green: 140.0 / 255.0, blue: 0, alpha: 1))
                .pngData()
        )

        #expect(actualData == expectedData)
    }
}
