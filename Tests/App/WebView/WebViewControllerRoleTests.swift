@testable import HomeAssistant
import XCTest

final class WebViewControllerRoleTests: XCTestCase {
    func testMainFrontendPinsNoPath() {
        XCTAssertTrue(WebViewControllerRole.mainFrontend.isMainFrontend)
        XCTAssertNil(WebViewControllerRole.mainFrontend.pinnedPath)
    }

    /// The frontend names the route; the role only carries it to the first load.
    func testNativeModalPinsTheRouteTheFrontendNamed() {
        let role = WebViewControllerRole.nativeModal(path: "/more-info?more-info-entity-id=light.kitchen")

        XCTAssertFalse(role.isMainFrontend)
        XCTAssertEqual(role.pinnedPath, "/more-info?more-info-entity-id=light.kitchen")
    }

    /// The pinned path is rebuilt onto whichever base URL is active, like a restored last page.
    func testNativeModalPathLandsOnTheActiveBaseURL() throws {
        let role = WebViewControllerRole.nativeModal(path: "/more-info?more-info-entity-id=climate.bedroom")
        let base = try XCTUnwrap(URL(string: "https://home.example:8123/lovelace/0"))

        let url = try WebViewController.restoredURL(base: base, relativePath: XCTUnwrap(role.pinnedPath))

        XCTAssertEqual(url?.absoluteString, "https://home.example:8123/more-info?more-info-entity-id=climate.bedroom")
    }

    /// A modal booted ahead of time has no route yet; it waits to be told one.
    func testNativeModalWithoutARoutePinsNothing() {
        XCTAssertNil(WebViewControllerRole.nativeModal(path: nil).pinnedPath)
    }
}
