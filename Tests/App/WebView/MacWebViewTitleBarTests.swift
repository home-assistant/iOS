@testable import HomeAssistant
@testable import Shared
import XCTest

final class MacWebViewTitleBarTests: XCTestCase {
    func testWindowTitleUsesServerName() {
        let server = Server.fake { $0.remoteName = "Office" }

        XCTAssertEqual(MacWebViewTitleBar.windowTitle(for: server), "Office")
    }

    func testWindowTitleFallsBackToAppNameWhenServerIsNil() {
        XCTAssertEqual(MacWebViewTitleBar.windowTitle(for: nil), L10n.About.Logo.title)
    }

    func testWindowTitleFallsBackToAppNameWhenServerNameIsBlank() {
        let server = Server.fake { $0.remoteName = "   " }

        XCTAssertEqual(MacWebViewTitleBar.windowTitle(for: server), L10n.About.Logo.title)
    }

    func testWindowTitlePrefersLocalNameOverRemoteName() {
        let server = Server.fake {
            $0.remoteName = "Remote"
            $0.setSetting(value: "Cottage", for: .localName)
        }

        XCTAssertEqual(MacWebViewTitleBar.windowTitle(for: server), "Cottage")
    }

    func testWindowTitleTracksServerRename() {
        let server = Server.fake { $0.remoteName = "Office" }

        XCTAssertEqual(MacWebViewTitleBar.windowTitle(for: server), "Office")

        server.update { $0.remoteName = "Studio" }

        XCTAssertEqual(MacWebViewTitleBar.windowTitle(for: server), "Studio")
    }
}
