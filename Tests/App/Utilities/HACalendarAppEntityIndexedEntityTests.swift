import CoreSpotlight
@testable import HomeAssistant
import Testing

/// A calendar's Spotlight entry shows its entity id as the second row and can be found by its server
/// and by its entity id spelled out, with the name paired with the server in both orders.
struct HACalendarAppEntityIndexedEntityTests {
    @available(iOS 18.0, *)
    @Test func theSpotlightEntryCarriesTheCalendarsContext() throws {
        let calendar = HACalendarAppEntity(
            id: "server-calendar.family_events",
            name: "Family",
            entityId: "calendar.family_events",
            serverId: "server",
            serverName: " Home "
        )

        let attributes = calendar.attributeSet

        #expect(attributes.contentDescription == "calendar.family_events")
        #expect(attributes.keywords == ["Home", "calendar.family_events", "calendar family events"])
        #expect(attributes.alternateNames == ["Family Home", "Home Family"])
    }

    @available(iOS 18.0, *)
    @Test func aCalendarWithoutAServerNameOnlyHasItsId() {
        let calendar = HACalendarAppEntity(
            id: "server-calendar.work",
            name: "Work",
            entityId: "calendar.work",
            serverId: "server",
            serverName: nil
        )

        let attributes = calendar.attributeSet

        #expect(attributes.keywords == ["calendar.work", "calendar work"])
        #expect(attributes.alternateNames?.isEmpty ?? true)
    }
}
