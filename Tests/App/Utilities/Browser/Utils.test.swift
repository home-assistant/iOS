@testable import HomeAssistant
import SafariServices
@testable import Shared
import UIKit
import XCTest

final class UtilsTests: XCTestCase {
    private static let prefsKeys = [
        "openInBrowser",
        "openInChrome",
        "openInPrivateTab",
        "confirmBeforeOpeningUrl",
        "lastInstalledBundleVersion",
        "lastInstalledShortVersion",
    ]

    private var previousURLOpener: URLOpening!
    private var previousPrefs: [String: Any] = [:]
    private var opener: MockURLOpener!

    override func setUp() {
        super.setUp()
        previousURLOpener = URLOpener.shared
        opener = MockURLOpener()
        opener.canOpenURLResult = false
        URLOpener.shared = opener

        previousPrefs = [:]
        for key in Self.prefsKeys {
            previousPrefs[key] = prefs.object(forKey: key)
        }
    }

    override func tearDown() {
        URLOpener.shared = previousURLOpener
        for key in Self.prefsKeys {
            if let value = previousPrefs[key] {
                prefs.set(value, forKey: key)
            } else {
                prefs.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    // MARK: - convertToDictionary

    func testConvertsAJSONObject() throws {
        let dictionary = try XCTUnwrap(convertToDictionary(text: #"{"name":"kitchen","count":2}"#))
        XCTAssertEqual(dictionary["name"] as? String, "kitchen")
        XCTAssertEqual(dictionary["count"] as? Int, 2)
    }

    func testDoesNotConvertAJSONArray() {
        XCTAssertNil(convertToDictionary(text: "[1, 2, 3]"))
    }

    func testDoesNotConvertInvalidJSON() {
        XCTAssertNil(convertToDictionary(text: "{not json"))
    }

    // MARK: - openURLInBrowser

    func testNonWebURLsGoStraightToTheSystem() {
        prefs.set(OpenInBrowser.SafariInApp.rawValue, forKey: "openInBrowser")
        let sender = PresentationRecorder()

        openURLInBrowser(URL(string: "tel:+15555550100")!, sender)

        XCTAssertEqual(opener.openedURLs.map(\.url.absoluteString), ["tel:+15555550100"])
        XCTAssertNil(sender.presented)
    }

    func testSafariOpensThroughTheSystem() {
        prefs.set(OpenInBrowser.Safari.rawValue, forKey: "openInBrowser")

        openURLInBrowser(URL(string: "https://example.com")!, nil)

        XCTAssertEqual(opener.openedURLs.map(\.url.absoluteString), ["https://example.com"])
    }

    func testUnknownPreferenceFallsBackToSafari() {
        prefs.set("Netscape", forKey: "openInBrowser")

        openURLInBrowser(URL(string: "https://example.com")!, nil)

        XCTAssertEqual(opener.openedURLs.map(\.url.absoluteString), ["https://example.com"])
    }

    func testSafariInAppPresentsASafariViewController() {
        prefs.set(OpenInBrowser.SafariInApp.rawValue, forKey: "openInBrowser")
        let sender = PresentationRecorder()

        openURLInBrowser(URL(string: "https://example.com")!, sender)

        XCTAssertTrue(sender.presented is SFSafariViewController)
        XCTAssertTrue(opener.openedURLs.isEmpty)
    }

    func testSafariInAppWithoutASenderOpensThroughTheSystem() {
        prefs.set(OpenInBrowser.SafariInApp.rawValue, forKey: "openInBrowser")

        openURLInBrowser(URL(string: "https://example.com")!, nil)

        XCTAssertEqual(opener.openedURLs.count, 1)
    }

    func testChromeOpensInChromeWhenInstalled() throws {
        prefs.set(OpenInBrowser.Chrome.rawValue, forKey: "openInBrowser")
        opener.canOpenURLResult = true

        openURLInBrowser(URL(string: "https://example.com/a")!, nil)

        let opened = try XCTUnwrap(opener.openedURLs.first?.url)
        XCTAssertEqual(opened.scheme, "googlechrome-x-callback")
    }

    func testChromeFallsBackWhenNotInstalled() {
        prefs.set(OpenInBrowser.Chrome.rawValue, forKey: "openInBrowser")

        openURLInBrowser(URL(string: "https://example.com/a")!, nil)

        XCTAssertEqual(opener.openedURLs.map(\.url.absoluteString), ["https://example.com/a"])
    }

    // MARK: - setDefaults

    func testSetDefaultsRecordsTheInstalledVersion() {
        setDefaults()

        XCTAssertEqual(prefs.string(forKey: "lastInstalledBundleVersion"), AppConstants.build)
        XCTAssertEqual(prefs.string(forKey: "lastInstalledShortVersion"), AppConstants.version)
    }

    func testSetDefaultsMigratesTheLegacyChromePreference() {
        prefs.removeObject(forKey: "openInBrowser")
        prefs.set(true, forKey: "openInChrome")

        setDefaults()

        XCTAssertEqual(prefs.string(forKey: "openInBrowser"), OpenInBrowser.Chrome.rawValue)
        XCTAssertNil(prefs.object(forKey: "openInChrome"))
    }

    func testSetDefaultsDefaultsToSafariAndConfirmingURLs() {
        prefs.removeObject(forKey: "openInBrowser")
        prefs.removeObject(forKey: "openInChrome")
        prefs.removeObject(forKey: "confirmBeforeOpeningUrl")

        setDefaults()

        XCTAssertEqual(prefs.string(forKey: "openInBrowser"), OpenInBrowser.Safari.rawValue)
        XCTAssertTrue(prefs.bool(forKey: "confirmBeforeOpeningUrl"))
    }

    func testSetDefaultsKeepsExistingChoices() {
        prefs.set(OpenInBrowser.Firefox.rawValue, forKey: "openInBrowser")
        prefs.set(false, forKey: "confirmBeforeOpeningUrl")

        setDefaults()

        XCTAssertEqual(prefs.string(forKey: "openInBrowser"), OpenInBrowser.Firefox.rawValue)
        XCTAssertFalse(prefs.bool(forKey: "confirmBeforeOpeningUrl"))
    }

    /// Records what it is asked to present instead of presenting it, so no window is needed.
    private final class PresentationRecorder: UIViewController {
        private(set) var presented: UIViewController?

        override func present(
            _ viewControllerToPresent: UIViewController,
            animated flag: Bool,
            completion: (() -> Void)? = nil
        ) {
            presented = viewControllerToPresent
            completion?()
        }
    }
}
