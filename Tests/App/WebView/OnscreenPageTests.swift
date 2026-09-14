import Foundation
@testable import HomeAssistant
import Testing

struct OnscreenPageTests {
    private static let panels: Set<String> = ["lovelace", "history", "config"]

    @Test("A dashboard URL resolves to the panel that owns it")
    func panelFromDashboardURL() throws {
        let url = try #require(URL(string: "https://example.com/lovelace/0"))
        let page = try #require(OnscreenPage(url: url, title: "Overview", serverId: "1", knownPanelPaths: Self.panels))

        #expect(page.panelPath == "lovelace")
        #expect(page.serverId == "1")
        #expect(page.title == "Overview")
    }

    @Test("A panel with no view of its own still resolves")
    func panelFromPanelRootURL() throws {
        let url = try #require(URL(string: "https://example.com/history"))
        let page = OnscreenPage(url: url, title: "History", serverId: "2", knownPanelPaths: Self.panels)

        #expect(page?.panelPath == "history")
    }

    /// A server reached under a path prefix puts the prefix where the panel would otherwise be, so the
    /// panel has to be matched rather than assumed to come first.
    @Test("A server under a path prefix still resolves to the panel")
    func panelBehindAPathPrefix() throws {
        let url = try #require(URL(string: "https://example.com/homeassistant/lovelace/0"))
        let page = OnscreenPage(url: url, title: "Overview", serverId: "1", knownPanelPaths: Self.panels)

        #expect(page?.panelPath == "lovelace")
    }

    /// Query and fragment belong to the view, not to the panel — the more info dialog writes its
    /// entity into the query string, and that must not become part of the page's identity.
    @Test("Query and fragment are not part of the panel path")
    func panelIgnoresQueryAndFragment() throws {
        let url = try #require(URL(string: "https://example.com/lovelace/0?more-info=light.kitchen#top"))
        let page = OnscreenPage(url: url, title: "Overview", serverId: "1", knownPanelPaths: Self.panels)

        #expect(page?.panelPath == "lovelace")
    }

    /// The root URL is whichever panel the server made default, which the URL alone does not say, so
    /// it yields no page rather than a guess.
    @Test("The root URL names no panel")
    func rootURLResolvesToNothing() throws {
        let url = try #require(URL(string: "https://example.com/"))

        #expect(OnscreenPage(url: url, title: "Home Assistant", serverId: "1", knownPanelPaths: Self.panels) == nil)
    }

    /// A path this server has no panel for would produce an identifier the widgets' own page query
    /// could not answer either.
    @Test("A path that is not one of this server's panels names nothing")
    func unknownPanelResolvesToNothing() throws {
        let url = try #require(URL(string: "https://example.com/some-custom-thing"))

        #expect(OnscreenPage(url: url, title: "Custom", serverId: "1", knownPanelPaths: Self.panels) == nil)
    }
}
