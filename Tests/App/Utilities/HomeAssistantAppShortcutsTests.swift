import AppIntents
import Foundation
@testable import HomeAssistant
import Testing
import UIKit

struct HomeAssistantAppShortcutsTests {
    /// Every `systemImageName` the provider hands out, in the order the shortcuts are offered.
    /// Kept in step with `HomeAssistantAppShortcuts.appShortcuts` by hand, as the phrases below are.
    private static let shortcutSymbols = [
        "lightswitch.on.fill",
        "lightswitch.off.fill",
        "info.circle",
        "arrow.up.forward.app",
        "thermometer",
        "sun.max",
        "curtains.open",
        "curtains.closed",
    ]

    /// The glyph is the only part of a Spotlight row a shortcut controls — the title is always the
    /// entity's name — so two shortcuts sharing a symbol are two rows nobody can tell apart. Turning
    /// on and turning off drew the same `power` for exactly that reason.
    @Test func noTwoShortcutsDrawTheSameSymbol() {
        #expect(Set(Self.shortcutSymbols).count == Self.shortcutSymbols.count)
    }

    /// A symbol name that names nothing draws a blank rather than failing to build, which is the kind
    /// of thing that ships: "curtains" did, for the open command, until this test went looking. Each
    /// one is resolved here instead, and every bad name is named at once so a run says which.
    @Test func everyShortcutSymbolIsARealSFSymbol() {
        let missing = Self.shortcutSymbols.filter { UIImage(systemName: $0) == nil }
        #expect(missing.isEmpty, "not SF Symbols: \(missing.joined(separator: ", "))")
    }

    /// One symbol per shortcut, so a shortcut added without one is caught here.
    @Test func everyShortcutHasASymbol() {
        guard #available(iOS 17.0, *) else { return }
        #expect(Self.shortcutSymbols.count == HomeAssistantAppShortcuts.appShortcuts.count)
    }

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

    /// Every shortcut that names an entity is labelled by its parameter presentation's summary. Without
    /// one, the system titles each of the rows it builds — one per shortcut per entity — with nothing
    /// but the entity's own name, so searching for a light returned half a dozen rows all reading
    /// "Chamber light", one of which dimmed it and one of which turned it off. These summaries are what
    /// write the verb into the row, and they are keyed off the same table the phrases are.
    @Test func everyEntityShortcutOffersASummary() throws {
        let strings = try Self.phrases(forLanguage: "en")
        #expect(strings.isSuperset(of: [
            "Turn on ${entity}",
            "Turn off ${entity}",
            "Is ${entity} on",
            "Open ${target} details",
            "Set ${entity} temperature",
            "Dim ${light}",
            "Open ${entity}",
            "Close ${entity}",
        ]))
    }

    /// Lock gave its slot to the shortcut above. A phrase left behind would still be handed to Siri,
    /// pointing at a shortcut that no longer exists.
    @Test func noLockPhrasesAreLeftBehind() throws {
        let phrases = try Self.phrases(forLanguage: "en")
        #expect(phrases.allSatisfy { !$0.localizedCaseInsensitiveContains("lock") })
    }

    /// These translations are written by hand rather than exported from Lokalise, so a language can
    /// end up a phrase or a summary short without anything else noticing.
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
