@testable import HomeAssistant
import UIKit
import XCTest

final class OpenInChromeControllerTests: XCTestCase {
    private var previousURLOpener: URLOpening!
    private var opener: SchemeOpener!
    private let sut = OpenInChromeController()

    override func setUp() {
        super.setUp()
        previousURLOpener = URLOpener.shared
        opener = SchemeOpener()
        URLOpener.shared = opener
    }

    override func tearDown() {
        URLOpener.shared = previousURLOpener
        super.tearDown()
    }

    func testChromeIsNotInstalledWhenNeitherSchemeOpens() {
        XCTAssertFalse(sut.isChromeInstalled())

        sut.openInChrome(URL(string: "https://example.com/a")!, callbackURL: nil)
        XCTAssertTrue(opener.opened.isEmpty)
    }

    func testChromeIsInstalledWhenEitherSchemeOpens() {
        opener.openableSchemes = ["googlechrome"]
        XCTAssertTrue(sut.isChromeInstalled())

        opener.openableSchemes = ["googlechrome-x-callback"]
        XCTAssertTrue(sut.isChromeInstalled())
    }

    func testOpensThroughTheCallbackScheme() throws {
        opener.openableSchemes = ["googlechrome", "googlechrome-x-callback"]

        sut.openInChrome(URL(string: "https://example.com/a")!, callbackURL: nil)

        let opened = try XCTUnwrap(opener.opened.first)
        XCTAssertEqual(opener.opened.count, 1)
        XCTAssertEqual(opened.scheme, "googlechrome-x-callback")
        XCTAssertTrue(opened.absoluteString.hasPrefix("googlechrome-x-callback://x-callback-url/open/?x-source="))
        XCTAssertTrue(opened.absoluteString.contains("&url=https://example.com/a"))
        XCTAssertFalse(opened.absoluteString.contains("x-success"))
        XCTAssertFalse(opened.absoluteString.contains("create-new-tab"))
    }

    func testCallbackSchemeCarriesTheSuccessURLAndNewTabFlag() throws {
        opener.openableSchemes = ["googlechrome-x-callback"]

        sut.openInChrome(
            URL(string: "http://example.com/b")!,
            callbackURL: URL(string: "homeassistant://done")!,
            createNewTab: true
        )

        let opened = try XCTUnwrap(opener.opened.first)
        XCTAssertTrue(opened.absoluteString.contains("&url=http://example.com/b"))
        XCTAssertTrue(opened.absoluteString.contains("&x-success=homeassistant://done"))
        XCTAssertTrue(opened.absoluteString.hasSuffix("&create-new-tab"))
    }

    func testCallbackSchemeIgnoresNonWebURLs() {
        opener.openableSchemes = ["googlechrome-x-callback"]

        sut.openInChrome(URL(string: "ftp://example.com/c")!, callbackURL: nil)

        XCTAssertTrue(opener.opened.isEmpty)
    }

    func testSimpleSchemeKeepsHTTPAndHTTPSApart() {
        opener.openableSchemes = ["googlechrome"]

        sut.openInChrome(URL(string: "http://example.com/a")!, callbackURL: nil)
        sut.openInChrome(URL(string: "https://example.com/b")!, callbackURL: nil)
        sut.openInChrome(URL(string: "mailto:someone@example.com")!, callbackURL: nil)

        XCTAssertEqual(opener.opened.map(\.scheme), ["googlechrome", "googlechromes"])
        XCTAssertTrue(opener.opened.first?.absoluteString.hasSuffix("example.com/a") == true)
        XCTAssertTrue(opener.opened.last?.absoluteString.hasSuffix("example.com/b") == true)
    }

    /// Answers `canOpenURL` per scheme, which `MockURLOpener` can't: Chrome has two schemes and the
    /// controller picks between them.
    private final class SchemeOpener: URLOpening {
        var openableSchemes: Set<String> = []
        private(set) var opened: [URL] = []

        func open(
            _ url: URL,
            options: [UIApplication.OpenExternalURLOptionsKey: Any],
            completionHandler completion: ((Bool) -> Void)?
        ) {
            opened.append(url)
            completion?(true)
        }

        func canOpenURL(_ url: URL) -> Bool {
            openableSchemes.contains(url.scheme ?? "")
        }

        func openSettings(destination: OpenSettingsDestination, completionHandler: ((Bool) -> Void)?) {
            completionHandler?(true)
        }
    }
}
