@testable import HomeAssistant
@testable import Shared
import Testing

/// How a calendar reads once the system shows it: the name as the user wrote it, with the entity id
/// underneath. Both are the user's own text, so neither may go through the strings table, which
/// would also reformat a name containing `%` or quotes.
struct HACalendarAppEntityTests {
    private func calendar(name: String) -> HACalendarAppEntity {
        HACalendarAppEntity(
            id: "server-calendar.bins",
            name: name,
            entityId: "calendar.bins",
            serverId: "server",
            serverName: "Home"
        )
    }

    @Test(arguments: ["Bin collection", "100% busy", "Mum's \"book club\""])
    func theTitleIsTheCalendarsOwnName(name: String) throws {
        let sut = calendar(name: name)

        #expect(String(localized: sut.displayRepresentation.title) == name)
    }

    @Test func theSubtitleIsTheEntityId() throws {
        let sut = calendar(name: "Bin collection")

        let subtitle = try #require(sut.displayRepresentation.subtitle)
        #expect(String(localized: subtitle) == "calendar.bins")
    }
}
