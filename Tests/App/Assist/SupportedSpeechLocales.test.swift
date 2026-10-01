import Foundation
@testable import HomeAssistant
import Testing

struct SupportedSpeechLocalesTests {
    private let english = [Locale(identifier: "en-US")]
    private let englishAndPortuguese = [Locale(identifier: "en-US"), Locale(identifier: "pt-BR")]

    /// The probe is close to a second of XPC, so everything that only reads the list shares one.
    @Test func probesOnceHoweverOftenTheListIsRead() async {
        let stub = SpeechLocaleProbeStub(answers: [english, englishAndPortuguese])
        let locales = SupportedSpeechLocales(probe: stub.probe)

        let first = await locales.locales()
        let second = await locales.locales()

        #expect(first == english)
        #expect(second == english)
        #expect(stub.probeCount == 1)
    }

    /// A language installed after the first probe has to be found without relaunching the app, and
    /// by everything that reads the list afterwards, not only by whoever asked for the refresh.
    @Test func refreshingFindsALanguageInstalledSinceTheLastProbe() async {
        let stub = SpeechLocaleProbeStub(answers: [english, englishAndPortuguese])
        let locales = SupportedSpeechLocales(probe: stub.probe)

        let beforeInstall = await locales.locales()
        let refreshed = await locales.refreshedLocales()
        let afterRefresh = await locales.locales()

        #expect(beforeInstall == english)
        #expect(refreshed == englishAndPortuguese)
        #expect(afterRefresh == englishAndPortuguese)
        #expect(stub.probeCount == 2)
    }

    /// Refreshing before anything was cached is just the first probe, not two of them.
    @Test func refreshingWithNothingCachedProbesOnce() async {
        let stub = SpeechLocaleProbeStub(answers: [englishAndPortuguese])
        let locales = SupportedSpeechLocales(probe: stub.probe)

        let refreshed = await locales.refreshedLocales()
        let cached = await locales.locales()

        #expect(refreshed == englishAndPortuguese)
        #expect(cached == englishAndPortuguese)
        #expect(stub.probeCount == 1)
    }
}
