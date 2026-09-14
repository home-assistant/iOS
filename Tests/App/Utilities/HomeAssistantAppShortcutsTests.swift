import AppIntents
import Foundation
@testable import HomeAssistant
import Testing

struct HomeAssistantAppShortcutsTests {
    /// Apple caps an app at ten, and `appintentsmetadataprocessor` fails the build on the eleventh.
    @Test func staysWithinTheShortcutLimit() {
        guard #available(iOS 17.0, *) else { return }
        #expect(HomeAssistantAppShortcuts.appShortcuts.count == 8)
        #expect(HomeAssistantAppShortcuts.appShortcuts.count <= 10)
    }

    @Test func tileColorIsSet() {
        guard #available(iOS 17.0, *) else { return }
        #expect(HomeAssistantAppShortcuts.shortcutTileColor == .lightBlue)
    }

    /// Siri only matches a phrase the localized table carries, so a phrase that loses its key is a
    /// shortcut nobody can say. These four open an entity's more-info dialog, and `${target}` is the
    /// parameter name of the intent behind them, which is what ties that slot to an `OpenIntent`
    /// taking a `target` — `ShowEntityDetailsAppIntent` — rather than to any other intent.
    @Test func theOpenEntityPhrasesAreOffered() throws {
        let phrases = try Self.phrases(forLanguage: "en")
        #expect(phrases.isSuperset(of: [
            "${applicationName} show ${target}",
            "Show ${target} in ${applicationName}",
            "Open ${target} details in ${applicationName}",
            "Show something in ${applicationName}",
        ]))
    }

    /// Lock gave its slot to the shortcut above. A phrase left behind would still be handed to Siri,
    /// pointing at a shortcut that no longer exists.
    @Test func noLockPhrasesAreLeftBehind() throws {
        let phrases = try Self.phrases(forLanguage: "en")
        #expect(phrases.allSatisfy { !$0.localizedCaseInsensitiveContains("lock") })
    }

    /// These translations are written by hand rather than exported from Lokalise, so a language can
    /// end up a phrase short without anything else noticing.
    @Test func everyLanguageCarriesTheSamePhrases() throws {
        let english = try Self.phrases(forLanguage: "en")
        for language in Self.bundle.localizations where language != "Base" {
            let phrases = try Self.phrases(forLanguage: language)
            #expect(phrases == english, "\(language) is out of step with English")
        }
    }

    /// The table is missing, or is not a string dictionary, for a language that should ship it.
    private struct UnreadablePhrases: Error {
        let language: String
    }

    private static let table = "AppShortcuts"

    private static var bundle: Bundle { Bundle(for: AppDelegate.self) }

    private static func phrases(forLanguage language: String) throws -> Set<String> {
        guard let url = bundle.url(
            forResource: table,
            withExtension: "strings",
            subdirectory: nil,
            localization: language
        ), let strings = NSDictionary(contentsOf: url) as? [String: String] else {
            throw UnreadablePhrases(language: language)
        }
        return Set(strings.keys)
    }
}
