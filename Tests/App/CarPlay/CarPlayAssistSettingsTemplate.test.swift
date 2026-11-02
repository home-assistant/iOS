import CarPlay
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Drives the CarPlay Assist settings screen through a fake navigator: the on-device speech toggles,
/// and the language and voice lists they reveal. The lists come from the simulator's own speech
/// catalog, so the tests only rely on what is always there (the default voice row).
@Suite(.sharedState)
@MainActor
struct CarPlayAssistSettingsTemplateTests {
    private typealias Rows = CarPlayTestRows

    private func withDatabase(_ body: (DatabaseQueue) async throws -> Void) async throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }
        let database = try CarPlayTestDatabase.make()
        Current.database = { database }
        try await body(database)
    }

    @Test func theScreenOffersBothOnDeviceToggles() async throws {
        try await withDatabase { _ in
            let navigator = FakeCarPlayNavigator()
            let sut = CarPlayAssistSettingsTemplate()
            sut.present(using: navigator)

            let template = try #require(navigator.pushedTemplates.last as? CPListTemplate)
            #expect(Rows.texts(template) == [
                L10n.Assist.Settings.OnDeviceStt.title,
                L10n.Assist.Settings.OnDeviceTts.title,
            ])
        }
    }

    @Test func turningOnSpeechRecognitionRevealsItsLanguage() async throws {
        try await withDatabase { _ in
            let navigator = FakeCarPlayNavigator()
            let sut = CarPlayAssistSettingsTemplate()
            sut.present(using: navigator)
            let template = try #require(navigator.pushedTemplates.last as? CPListTemplate)

            Rows.tap(Rows.row(template, L10n.Assist.Settings.OnDeviceStt.title))
            #expect(AssistConfiguration.config.enableOnDeviceSTT)
            #expect(Rows.texts(template).contains(L10n.Assist.Settings.OnDeviceStt.language))
            // Let the default-locale probe the toggle started finish against the same cache.
            _ = await SupportedSpeechLocales.shared.locales()

            Rows.tap(Rows.row(template, L10n.Assist.Settings.OnDeviceStt.language))
            let languages = try #require(navigator.pushedTemplates.last as? CPListTemplate)
            let filled = await carPlayEventually { languages.sections.count == 1 }
            #expect(filled)
            if let first = Rows.listItems(languages).first {
                Rows.tap(first)
                #expect(navigator.popCount == 1)
                #expect(AssistConfiguration.config.onDeviceSTTLocaleIdentifier != nil)
            }

            Rows.tap(Rows.row(template, L10n.Assist.Settings.OnDeviceStt.title))
            #expect(!AssistConfiguration.config.enableOnDeviceSTT)
        }
    }

    @Test func turningOnOnDeviceVoicesRevealsTheVoiceList() async throws {
        try await withDatabase { _ in
            let navigator = FakeCarPlayNavigator()
            let sut = CarPlayAssistSettingsTemplate()
            sut.present(using: navigator)
            let template = try #require(navigator.pushedTemplates.last as? CPListTemplate)

            Rows.tap(Rows.row(template, L10n.Assist.Settings.OnDeviceTts.title))
            #expect(AssistConfiguration.config.enableOnDeviceTTS)
            let voiceRow = try #require(Rows.row(template, L10n.Assist.Settings.OnDeviceTts.voice))
            #expect(voiceRow.detailText == L10n.Assist.Settings.OnDeviceTts.defaultVoice)

            Rows.tap(voiceRow)
            let voices = try #require(navigator.pushedTemplates.last as? CPListTemplate)
            let filled = await carPlayEventually { voices.sections.count == 1 }
            #expect(filled)
            let rows = Rows.listItems(voices)
            #expect(rows.first?.text == L10n.Assist.Settings.OnDeviceTts.defaultVoice)

            if rows.count > 1 {
                Rows.tap(rows[1])
                #expect(AssistConfiguration.config.onDeviceTTSVoiceIdentifier != nil)
            }
            Rows.tap(rows.first)
            #expect(AssistConfiguration.config.onDeviceTTSVoiceIdentifier == nil)
            #expect(navigator.popCount == (rows.count > 1 ? 2 : 1))
        }
    }

    /// A voice saved earlier shows by name once the catalog answers, and stays offered even when it
    /// is not in the device language.
    @Test func aSavedVoiceIsNamedAndOffered() async throws {
        let voices = await OnDeviceVoiceCatalog.voices()
        let languageCode = Locale.current.language.languageCode?.identifier ?? Locale.current.identifier
        guard let foreign = voices.first(where: { !$0.language.hasPrefix(languageCode) }) ?? voices.first else {
            return
        }
        try await withDatabase { _ in
            var configuration = AssistConfiguration.config
            configuration.enableOnDeviceTTS = true
            configuration.onDeviceTTSVoiceIdentifier = foreign.identifier
            configuration.save()

            let navigator = FakeCarPlayNavigator()
            let sut = CarPlayAssistSettingsTemplate()
            sut.present(using: navigator)
            let template = try #require(navigator.pushedTemplates.last as? CPListTemplate)
            let named = await carPlayEventually {
                Rows.row(template, L10n.Assist.Settings.OnDeviceTts.voice)?.detailText == foreign.name
            }
            #expect(named)

            Rows.tap(Rows.row(template, L10n.Assist.Settings.OnDeviceTts.voice))
            let list = try #require(navigator.pushedTemplates.last as? CPListTemplate)
            let filled = await carPlayEventually { list.sections.count == 1 }
            #expect(filled)
            #expect(Rows.texts(list).contains(foreign.name))
        }
    }
}
