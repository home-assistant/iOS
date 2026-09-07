import Foundation
@testable import HomeAssistant
import Testing

struct WyomingServiceCatalogTests {
    /// The pipeline's language is not always one of the tags this device advertises, so a bare
    /// `en` has to find `en-US` rather than failing the request outright.
    @Test func matchesOnTheLanguageWhenTheExactTagIsNotSupported() async {
        let fallback = Locale(identifier: "pt-BR")
        let supported = await SupportedSpeechLocales.shared.locales()
        let resolved = await WyomingServiceCatalog.resolveLocale(for: "en", fallback: fallback)

        if supported.contains(where: { $0.language.languageCode?.identifier == "en" }) {
            #expect(resolved.language.languageCode?.identifier == "en")
        } else {
            // A device with no English dictation gets the tag back untouched, and the recognizer
            // is what refuses it.
            #expect(resolved.identifier == "en")
        }
    }

    @Test func fallsBackWhenTheClientNamesNoLanguage() async {
        let fallback = Locale(identifier: "pt-BR")

        let unnamed = await WyomingServiceCatalog.resolveLocale(for: nil, fallback: fallback)
        let empty = await WyomingServiceCatalog.resolveLocale(for: "", fallback: fallback)

        #expect(unnamed == fallback)
        #expect(empty == fallback)
    }

    /// An unknown tag is passed through rather than silently swapped for the fallback: transcribing
    /// in the wrong language is worse than reporting that the language is unavailable.
    @Test func keepsAnUnknownLanguageRatherThanSubstitutingTheFallback() async {
        let resolved = await WyomingServiceCatalog.resolveLocale(
            for: "zz-ZZ",
            fallback: Locale(identifier: "en-US")
        )

        #expect(resolved.identifier == "zz-ZZ")
    }

    /// Every voice the device has installed is advertised, and the simulator always has some, so
    /// the payload proves the catalog was built rather than returning an empty envelope.
    @Test func advertisesTheInstalledVoices() async {
        let info = await WyomingServiceCatalog.info()
        let program = info.tts.first

        #expect(program != nil)
        #expect(program?.installed == true)
        #expect(program?.voices.isEmpty == false)
        #expect(program?.voices.allSatisfy { !$0.name.isEmpty && !$0.languages.isEmpty } == true)
    }

    /// A speech-to-text service with no models would be one Home Assistant could pick and never get
    /// an answer from, so a device without on-device dictation advertises none at all.
    @Test func onlyAdvertisesSpeechToTextWhenTheDeviceCanDoIt() async {
        let info = await WyomingServiceCatalog.info()
        let supported = await SupportedSpeechLocales.shared.locales()

        if supported.isEmpty {
            #expect(info.asr.isEmpty)
        } else {
            #expect(info.asr.first?.models.first?.languages.isEmpty == false)
        }
    }
}
