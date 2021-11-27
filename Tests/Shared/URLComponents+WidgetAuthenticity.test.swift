@testable import Shared
import XCTest

class URLComponentsWidgetAuthenticityTests: XCTestCase {
    func testNotAuthentic() throws {
        for urlString in [
            "homeassistant://navigate/bad",
            "homeassistant://navigate/bad?widgetAuthenticity=fake",
            "homeassistant://navigate/bad?widgetAuthenticity=",
        ] {
            var components = try XCTUnwrap(URLComponents(string: urlString))
            XCTAssertFalse(components.popWidgetAuthenticity())
            XCTAssertEqual(components.string, urlString)
        }
    }

    func testInsertRemoveDoesntChangeString() throws {
        for urlString in [
            // no query string
            "homeassistant://navigate/good",
            // some query string
            "homeassistant://navigate/good?example=test&dog=cat",
            // already has one for some reason and it's bad
            "homeassistant://navigate/good?widgetAuthenticity=bad",
        ] {
            do {
                var components = try XCTUnwrap(URLComponents(string: urlString))
                components.insertWidgetAuthenticity()
                XCTAssertNotEqual(components.string, urlString)
                XCTAssertEqual(components.query?.contains(Current.settingsStore.widgetAuthenticityToken), true)
                XCTAssertTrue(components.popWidgetAuthenticity())
                XCTAssertEqual(components.string, urlString)
            }

            do {
                let originalURL = try XCTUnwrap(URL(string: urlString))
                XCTAssertEqual(originalURL.absoluteString, urlString)
                let url = originalURL.withWidgetAuthenticity()
                XCTAssertNotEqual(url.absoluteString, urlString)
                var components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: true))
                XCTAssertTrue(components.popWidgetAuthenticity())
                XCTAssertEqual(components.string, urlString)
            }
        }
    }

    func testInsertServer() throws {
        let servers = FakeServerManager(initial: 1)
        let server = servers.all[0]
        Current.servers = servers

        var baseUrl = try XCTUnwrap(URLComponents(string: "homeassistant://navigate/path"))
        baseUrl.insertWidgetServer(server: server)

        XCTAssertNil(baseUrl.popWidgetServer(isFromWidget: false))

        let popped = baseUrl.popWidgetServer(isFromWidget: true)
        XCTAssertEqual(popped, server)
    }
}
