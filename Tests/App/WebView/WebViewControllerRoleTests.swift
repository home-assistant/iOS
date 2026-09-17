@testable import HomeAssistant
import XCTest

final class WebViewControllerRoleTests: XCTestCase {
    func testMainFrontendPinsNoPath() {
        XCTAssertTrue(WebViewControllerRole.mainFrontend.isMainFrontend)
        XCTAssertNil(WebViewControllerRole.mainFrontend.pinnedPath)
    }

    func testStandaloneMoreInfoPinsTheFrontendPageForTheEntity() {
        let role = WebViewControllerRole.standaloneMoreInfo(entityId: "light.kitchen")

        XCTAssertFalse(role.isMainFrontend)
        XCTAssertEqual(role.pinnedPath, "/more-info?more-info-entity-id=light.kitchen")
    }

    /// The pinned path is rebuilt onto whichever base URL is active, like a restored last page.
    func testStandaloneMoreInfoPathLandsOnTheActiveBaseURL() throws {
        let role = WebViewControllerRole.standaloneMoreInfo(entityId: "climate.bedroom")
        let base = try XCTUnwrap(URL(string: "https://home.example:8123/lovelace/0"))

        let url = try WebViewController.restoredURL(base: base, relativePath: XCTUnwrap(role.pinnedPath))

        XCTAssertEqual(url?.absoluteString, "https://home.example:8123/more-info?more-info-entity-id=climate.bedroom")
    }

    /// A sheet booted ahead of time has no entity yet; the page waits to be told one.
    func testStandaloneMoreInfoWithoutAnEntityPinsTheBarePage() {
        XCTAssertEqual(WebViewControllerRole.standaloneMoreInfo(entityId: nil).pinnedPath, "/more-info")
    }

    func testStandaloneMoreInfoPathEscapesTheEntityId() throws {
        let path = WebViewControllerRole.standaloneMoreInfoPath(entityId: "sensor.a&b c")

        let components = try XCTUnwrap(URLComponents(string: path))
        XCTAssertEqual(components.path, "/more-info")
        XCTAssertEqual(components.queryItems?.count, 1)
        XCTAssertEqual(components.queryItems?.first?.name, "more-info-entity-id")
        XCTAssertEqual(components.queryItems?.first?.value, "sensor.a&b c")
    }
}
