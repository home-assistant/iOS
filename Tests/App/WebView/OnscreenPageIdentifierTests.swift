import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@available(iOS 18.0, *)
@Suite(.serialized)
struct OnscreenPageIdentifierTests {
    @Test("A page resolves to an identifier keyed the way the widgets' page entity is")
    func pageResolvesToAnIdentifier() throws {
        try withExposureDatabase {
            let page = try Self.page()

            #expect(OnscreenPageIdentifier.make(for: page) != nil)
            #expect(PageAppEntity.makeId(serverId: "1", panelPath: "lovelace") == "1-lovelace")
        }
    }

    /// Saying which page someone is looking at is a stronger disclosure than listing the pages they
    /// could open, so hiding a server from Siri has to hide its screens too.
    @Test("A server hidden from Siri publishes no page")
    func hiddenServerPublishesNothing() throws {
        try withExposureDatabase {
            let page = try Self.page()
            SiriServerExposure.setExposed(false, serverId: "1")

            #expect(OnscreenPageIdentifier.make(for: page) == nil)
        }
    }

    /// Built through the initializer so the test resolves the panel the way the app does.
    private static func page() throws -> OnscreenPage {
        let url = try #require(URL(string: "https://example.com/lovelace/0"))
        return try #require(
            OnscreenPage(url: url, title: "Overview", serverId: "1", knownPanelPaths: ["lovelace"])
        )
    }

    private func withExposureDatabase(perform work: () throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")

        try SiriServerExposureTable().createIfNeeded(database: database)
        Current.database = { database }

        defer { Current.database = previousDatabase }

        try work()
    }
}
