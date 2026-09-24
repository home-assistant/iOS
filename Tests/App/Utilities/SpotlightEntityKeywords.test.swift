@testable import HomeAssistant
import Shared
import Testing

/// The terms Spotlight indexes for an entity beyond its name. A child device only carries its own
/// part name ("Outlet 2"), so the hardware it belongs to has to be searchable too.
struct SpotlightEntityKeywordsTests {
    @Test("The parent device is searchable alongside the entity's own device")
    func keywordsIncludeTheParentDevice() throws {
        guard #available(iOS 18.0, *) else { return }
        let attributes = entity(deviceName: "Outlet 2", parentDeviceName: "Power strip").attributeSet
        let keywords = try #require(attributes.keywords)

        #expect(keywords.contains("Outlet 2"))
        #expect(keywords.contains("Power strip"))
        // The name paired with each piece of context, in both orders.
        let alternateNames = try #require(attributes.alternateNames)
        #expect(alternateNames.contains("Power Power strip"))
        #expect(alternateNames.contains("Power strip Power"))
    }

    @Test("An entity with no parent device indexes no empty term")
    func keywordsOmitAnAbsentParent() throws {
        guard #available(iOS 18.0, *) else { return }
        let attributes = entity(deviceName: "Ceiling lamp", parentDeviceName: nil).attributeSet
        let keywords = try #require(attributes.keywords)

        #expect(keywords.contains("Ceiling lamp"))
        #expect(!keywords.contains(""))
    }

    @Test("A parent named after the device it owns is indexed once")
    func keywordsDeduplicateARepeatedName() throws {
        guard #available(iOS 18.0, *) else { return }
        let attributes = entity(deviceName: "Power strip", parentDeviceName: "power strip").attributeSet
        let keywords = try #require(attributes.keywords)

        #expect(keywords.filter { $0.lowercased() == "power strip" }.count == 1)
    }

    private func entity(deviceName: String, parentDeviceName: String?) -> HAAppEntityAppIntentEntity {
        .init(
            id: "1-switch.outlet_power",
            entityId: "switch.outlet_power",
            serverId: "1",
            serverName: "Home",
            areaName: "Kitchen",
            deviceName: deviceName,
            parentDeviceName: parentDeviceName,
            floorName: nil,
            displayString: "Power",
            iconName: "mdi:power-socket-eu"
        )
    }
}
