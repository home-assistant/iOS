import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Where a link opens: the browser preference picks Chrome (through its x-callback or plain URL
/// scheme), Firefox and its variants when installed, Safari in the app, or the system; the launch
/// defaults migrate the old Chrome toggle; and JSON strings convert to dictionaries.
///
/// `.sharedState`: the tests swap `URLOpener.shared` and write the app group preferences.
@Suite(.sharedState)
@MainActor
struct OpenURLInBrowserTests {
    /// Answers `canOpenURL` per scheme and records what was opened.
    private final class SchemeOpener: URLOpening {
        var openableSchemes: Set<String>
        var opened: [URL] = []

        init(openableSchemes: Set<String> = []) {
            self.openableSchemes = openableSchemes
        }

        func open(
            _ url: URL,
            options: [UIApplication.OpenExternalURLOptionsKey: Any],
            completionHandler completion: ((Bool) -> Void)?
        ) {
            opened.append(url)
            completion?(true)
        }

        func canOpenURL(_ url: URL) -> Bool {
            openableSchemes.contains(url.scheme ?? url.absoluteString)
        }

        func openSettings(destination: OpenSettingsDestination, completionHandler: ((Bool) -> Void)?) {
            completionHandler?(true)
        }
    }

    private static let preferenceKeys = [
        "openInBrowser", "openInPrivateTab", "openInChrome", "confirmBeforeOpeningUrl",
        "lastInstalledBundleVersion", "lastInstalledShortVersion",
    ]

    private func withOpener(_ opener: SchemeOpener, _ body: () throws -> Void) rethrows {
        let previousOpener = URLOpener.shared
        let previousValues = Self.preferenceKeys.map { prefs.object(forKey: $0) }
        URLOpener.shared = opener
        defer {
            URLOpener.shared = previousOpener
            for (key, value) in zip(Self.preferenceKeys, previousValues) {
                prefs.set(value, forKey: key)
            }
        }
        try body()
    }

    private let page = URL(string: "https://www.home-assistant.io/path?q=1")!

    @Test func nonWebLinksGoToTheSystem() {
        let opener = SchemeOpener()
        withOpener(opener) {
            let url = URL(string: "homeassistant://navigate/lovelace")!
            openURLInBrowser(url, nil)
            #expect(opener.opened == [url])
        }
    }

    @Test(arguments: [OpenInBrowser.Safari, .Firefox, .FirefoxFocus, .FirefoxKlar, .Chrome])
    func uninstalledBrowsersFallBackToTheSystem(_ browser: OpenInBrowser) {
        let opener = SchemeOpener()
        withOpener(opener) {
            prefs.set(browser.rawValue, forKey: "openInBrowser")
            openURLInBrowser(page, nil)
            #expect(opener.opened == [page])
        }
    }

    @Test func safariInAppNeedsAPresenter() {
        let opener = SchemeOpener()
        withOpener(opener) {
            prefs.set(OpenInBrowser.SafariInApp.rawValue, forKey: "openInBrowser")
            // The presenter isn't in a window, so nothing appears; nothing goes to the system either.
            openURLInBrowser(page, UIViewController())
            #expect(opener.opened.isEmpty)
            openURLInBrowser(page, nil)
            #expect(opener.opened == [page])
        }
    }

    @Test func chromeOpensThroughItsCallbackScheme() throws {
        let opener = SchemeOpener(openableSchemes: ["googlechrome-x-callback", "googlechrome"])
        try withOpener(opener) {
            prefs.set(OpenInBrowser.Chrome.rawValue, forKey: "openInBrowser")
            openURLInBrowser(page, nil)
            let opened = try #require(opener.opened.first)
            #expect(opened.scheme == "googlechrome-x-callback")
            #expect(opened.absoluteString.contains("x-callback-url/open/"))

            opener.opened = []
            let callback = URL(string: "homeassistant://done")!
            OpenInChromeController.sharedInstance.openInChrome(page, callbackURL: callback, createNewTab: true)
            let withCallback = try #require(opener.opened.first)
            #expect(withCallback.absoluteString.contains("x-success="))
            #expect(withCallback.absoluteString.hasSuffix("&create-new-tab"))

            // Only web links are handed to Chrome.
            opener.opened = []
            OpenInChromeController.sharedInstance.openInChrome(URL(string: "mailto:a@b.c")!, callbackURL: nil)
            #expect(opener.opened.isEmpty)
        }
    }

    @Test func chromeOpensThroughItsPlainSchemes() throws {
        let opener = SchemeOpener(openableSchemes: ["googlechrome"])
        withOpener(opener) {
            #expect(OpenInChromeController.sharedInstance.isChromeInstalled())
            OpenInChromeController.sharedInstance.openInChrome(URL(string: "http://example.com/a")!, callbackURL: nil)
            OpenInChromeController.sharedInstance.openInChrome(page, callbackURL: nil)
            OpenInChromeController.sharedInstance.openInChrome(URL(string: "ftp://example.com")!, callbackURL: nil)
            // http goes to `googlechrome`, https to `googlechromes`; other schemes aren't handed over.
            let opened = opener.opened.map(\.absoluteString)
            #expect(opened.count == 2)
            #expect(opened.first?.hasPrefix("googlechrome:") == true)
            #expect(opened.first?.hasSuffix("//example.com/a") == true)
            #expect(opened.last?.hasPrefix("googlechromes:") == true)
            #expect(opened.last?.hasSuffix("//www.home-assistant.io/path?q=1") == true)

            opener.openableSchemes = []
            #expect(!OpenInChromeController.sharedInstance.isChromeInstalled())
            OpenInChromeController.sharedInstance.openInChrome(page, callbackURL: nil)
            #expect(opener.opened.count == 2)
        }
    }

    @Test(arguments: [false, true])
    func firefoxBuildsItsOpenURL(_ privateTab: Bool) {
        for controller in [
            OpenInFirefoxControllerSwift(),
            OpenInFirefoxControllerSwift(type: .focus),
            OpenInFirefoxControllerSwift(type: .klar),
        ] {
            // Not installed in the simulator: asking says so, and opening its unhandled scheme does
            // nothing. Only web links are handed over at all.
            _ = controller.isFirefoxInstalled()
            controller.openInFirefox(page, privateTab: privateTab)
            controller.openInFirefox(URL(string: "mailto:a@b.c")!, privateTab: privateTab)
        }
        #expect(OpenInFirefoxControllerSwift.FirefoxType.klar.urlScheme == "firefox-klar")
    }

    @Test func launchDefaultsMigrateTheChromeToggle() {
        withOpener(SchemeOpener()) {
            prefs.removeObject(forKey: "openInBrowser")
            prefs.set(true, forKey: "openInChrome")
            prefs.removeObject(forKey: "confirmBeforeOpeningUrl")
            setDefaults()
            #expect(prefs.string(forKey: "openInBrowser") == OpenInBrowser.Chrome.rawValue)
            #expect(prefs.object(forKey: "openInChrome") == nil)
            #expect(prefs.bool(forKey: "confirmBeforeOpeningUrl"))
            #expect(prefs.string(forKey: "lastInstalledShortVersion") == AppConstants.version)

            prefs.removeObject(forKey: "openInBrowser")
            setDefaults()
            #expect(prefs.string(forKey: "openInBrowser") == OpenInBrowser.Safari.rawValue)

            // An explicit choice is kept.
            prefs.set(OpenInBrowser.FirefoxFocus.rawValue, forKey: "openInBrowser")
            prefs.set(false, forKey: "confirmBeforeOpeningUrl")
            setDefaults()
            #expect(prefs.string(forKey: "openInBrowser") == OpenInBrowser.FirefoxFocus.rawValue)
            #expect(!prefs.bool(forKey: "confirmBeforeOpeningUrl"))
        }
    }

    @Test func jsonStringsConvertToDictionaries() {
        #expect(convertToDictionary(text: "{\"a\": 1, \"b\": \"two\"}")?["b"] as? String == "two")
        #expect(convertToDictionary(text: "[1, 2]") == nil)
        #expect(convertToDictionary(text: "not json") == nil)
    }
}
