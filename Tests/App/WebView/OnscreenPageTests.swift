@testable import HomeAssistant
import Testing

struct OnscreenPageTests {
    @Test("A dashboard URL resolves to the panel that owns it")
    func panelFromDashboardURL() throws {
        let url = try #require(URL(string: "https://example.com/lovelace/0"))
        let page = try #require(OnscreenPage(url: url, title: "Overview", serverId: "1"))

        #expect(page.panelPath == "lovelace")
        #expect(page.serverId == "1")
        #expect(page.title == "Overview")
    }

    @Test("A panel with no view of its own still resolves")
    func panelFromPanelRootURL() throws {
        let url = try #require(URL(string: "https://example.com/history"))

        #expect(OnscreenPage(url: url, title: "History", serverId: "2")?.panelPath == "history")
    }

    /// Query and fragment belong to the view, not to the panel — the more info dialog writes its
    /// entity into the query string, and that must not become part of the page's identity.
    @Test("Query and fragment are not part of the panel path")
    func panelIgnoresQueryAndFragment() throws {
        let url = try #require(URL(string: "https://example.com/lovelace/0?more-info=light.kitchen#top"))

        #expect(OnscreenPage(url: url, title: "Overview", serverId: "1")?.panelPath == "lovelace")
    }

    /// The root URL is whichever panel the server made default, which the URL alone does not say, so
    /// it yields no page rather than a guess.
    @Test("The root URL names no panel")
    func rootURLResolvesToNothing() throws {
        let url = try #require(URL(string: "https://example.com/"))

        #expect(OnscreenPage(url: url, title: "Home Assistant", serverId: "1") == nil)
    }
}
