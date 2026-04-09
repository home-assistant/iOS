import Foundation
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Regression tests for kiosk L10n format strings across all bundled locales.
///
/// Guards against issue #4487, in which German and Dutch translations of
/// `kiosk.security.gesture_footer` reordered format specifiers without using
/// positional markers (`%N$...`), causing `String(format:)` to misinterpret a
/// CVarArg as the wrong type and crash (EXC_BAD_ACCESS) when the Kiosk
/// settings view body was evaluated.
///
/// These tests exercise every kiosk format-string key against every bundled
/// `*.lproj/Localizable.strings` file, confirming the format call completes
/// without crashing and returns non-empty output containing the supplied
/// argument values.
final class KioskLocalizationTests: XCTestCase {
    /// Kiosk format-string keys that take at least one argument, paired with
    /// representative invocation args. Args are strings because the current
    /// SwiftGen output coerces all args with `String(describing:)` before
    /// passing to `String(format:)` — this test mirrors the runtime path.
    private static let kioskFormatKeys: [(key: String, args: [CVarArg], specifiers: Int)] = [
        ("kiosk.brightness.manual", [80 as Int], 1),
        ("kiosk.screensaver.dim_level", [25 as Int], 1),
        ("kiosk.clock.accessibility.analog_clock", ["3:45 PM"], 1),
        ("kiosk.clock.accessibility.current_time", ["3:45 PM"], 1),
        ("kiosk.clock.accessibility.date", ["Wednesday, April 8"], 1),
        ("kiosk.security.taps_required", [5 as Int], 1),
        ("kiosk.security.gesture_footer", ["top-left", "5"], 2),
    ]

    func testKioskFormatStringsAcrossAllLocales() throws {
        // Matches a single printf-style format specifier, e.g. `%@`, `%li`, `%1$@`.
        let specifierRegex = try NSRegularExpression(
            pattern: "%{1,2}[+0123456789$.luq]*?[sduiefgcCp@]"
        )
        let bundle = Bundle(for: AppDelegate.self)

        let lprojURLs: [URL] = try {
            let resourceURL = try XCTUnwrap(bundle.resourceURL)
            let enumerator = try XCTUnwrap(FileManager.default.enumerator(
                at: resourceURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsSubdirectoryDescendants]
            ))
            return enumerator.compactMap { $0 as? URL }
                .filter { $0.pathExtension == "lproj" }
                .filter { $0.deletingPathExtension().lastPathComponent != "Base" }
        }()

        XCTAssertGreaterThan(lprojURLs.count, 1, "Expected multiple bundled locales")

        for lprojURL in lprojURLs {
            let language = lprojURL.deletingPathExtension().lastPathComponent
            let stringsURL = lprojURL.appendingPathComponent("Localizable.strings")
            guard let strings = NSDictionary(contentsOf: stringsURL) as? [String: String] else {
                XCTFail("Could not load Localizable.strings for locale \(language)")
                continue
            }

            for (key, args, expectedSpecifiers) in Self.kioskFormatKeys {
                guard let format = strings[key] else {
                    // Missing key is acceptable (fallback to English via LocalizedManager)
                    continue
                }

                let specifierCount = specifierRegex.numberOfMatches(
                    in: format,
                    range: NSRange(location: 0, length: format.utf16.count)
                )
                XCTAssertEqual(
                    specifierCount,
                    expectedSpecifiers,
                    "Locale '\(language)' key '\(key)' has \(specifierCount) format specifiers, expected \(expectedSpecifiers): \(format)"
                )

                // Execute the format call — this is the path that crashed in #4487.
                let result = String(format: format, locale: Locale(identifier: language), arguments: args)
                XCTAssertFalse(
                    result.isEmpty,
                    "Locale '\(language)' key '\(key)' produced empty result"
                )
                // Every supplied arg must appear in the output, confirming each specifier consumed a value.
                for arg in args {
                    let argString: String
                    if let s = arg as? String {
                        argString = s
                    } else if let i = arg as? Int {
                        argString = "\(i)"
                    } else {
                        continue
                    }
                    XCTAssertTrue(
                        result.contains(argString),
                        "Locale '\(language)' key '\(key)' output '\(result)' missing arg '\(argString)'"
                    )
                }
            }
        }
    }

    /// Targeted regression test for issue #4487: exercises the real
    /// `L10n.Kiosk.Security.gestureFooter` function via the app's
    /// `LocalizedManager`, once per bundled locale, by injecting a string
    /// provider that returns that locale's format string.
    func testGestureFooterDoesNotCrashAcrossLocales() throws {
        let bundle = Bundle(for: AppDelegate.self)
        let resourceURL = try XCTUnwrap(bundle.resourceURL)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsSubdirectoryDescendants]
        ))
        let lprojURLs = enumerator.compactMap { $0 as? URL }
            .filter { $0.pathExtension == "lproj" }
            .filter { $0.deletingPathExtension().lastPathComponent != "Base" }

        let savedLocalized = Current.localized
        defer { Current.localized = savedLocalized }

        for lprojURL in lprojURLs {
            let language = lprojURL.deletingPathExtension().lastPathComponent
            let stringsURL = lprojURL.appendingPathComponent("Localizable.strings")
            guard let strings = NSDictionary(contentsOf: stringsURL) as? [String: String],
                  let format = strings["kiosk.security.gesture_footer"] else {
                continue
            }

            // Inject this locale's format into the LocalizedManager.
            let localized = LocalizedManager()
            localized.add(stringProvider: { request in
                request.key == "kiosk.security.gesture_footer" ? format : nil
            })
            Current.localized = localized

            // Call the generated L10n function — this is the exact path
            // KioskSettingsView exercises when rendering the footer.
            let result = L10n.Kiosk.Security.gestureFooter("top-left", String(5))
            XCTAssertFalse(
                result.isEmpty,
                "Locale '\(language)' gestureFooter produced empty result"
            )
        }
    }
}
