import AVFoundation
import Foundation
import Shared

/// Builds the `info` this device advertises: the locales its speech recogniser handles on device
/// and every text-to-speech voice installed on it.
///
/// Both lists are slow to work out — probing the locales is close to a second of XPC, and reading
/// the voices waits on the TextToSpeech daemon — so this is only ever called from the connection
/// answering a `describe`, never from a view.
enum WyomingServiceCatalog {
    /// The recognition model's id. Unlike the program name it is not shown to anyone: it names
    /// what does the work, and stays the same on every device.
    static let asrModelName = "apple-on-device-speech"

    /// Maps the language a client asks to transcribe onto a locale this device actually recognises.
    ///
    /// Home Assistant's pipeline language is not always one of the tags advertised here — it can be
    /// a bare `en` where the device only offers `en-US` — and an unmatched tag would fail the
    /// request outright, so the language is matched on its own before giving up.
    static func resolveLocale(for language: String?, fallback: Locale) async -> Locale {
        guard let language, !language.isEmpty else { return fallback }
        let requested = Locale(identifier: language)
        let supported = await SupportedSpeechLocales.shared.locales()

        if supported.contains(where: { $0.identifier == requested.identifier }) {
            return requested
        }
        if let languageCode = requested.language.languageCode?.identifier,
           let match = supported.first(where: { $0.language.languageCode?.identifier == languageCode }) {
            return match
        }
        return requested
    }

    static func info() async -> WyomingInfo {
        let version = Current.clientVersion().description
        // Home Assistant titles the config entry after the first program it finds, so the programs
        // are named after the device: "Bruno's iPhone" identifies which phone was added, where
        // "apple-on-device-speech" would be the same on every one of them.
        let deviceName = Current.device.deviceName()
        let attribution = WyomingInfo.Attribution(
            name: "Home Assistant Companion",
            url: "https://companion.home-assistant.io"
        )

        async let locales = SupportedSpeechLocales.shared.locales()
        async let voices = OnDeviceVoiceCatalog.voices()

        return await WyomingInfo(
            asr: asrPrograms(
                locales: locales,
                deviceName: deviceName,
                attribution: attribution,
                version: version
            ),
            tts: ttsPrograms(
                voices: voices,
                deviceName: deviceName,
                attribution: attribution,
                version: version
            )
        )
    }

    /// An empty model list would still advertise a speech-to-text service Home Assistant could pick
    /// and then never get an answer from, so a device with no on-device dictation advertises none.
    private static func asrPrograms(
        locales: [Locale],
        deviceName: String,
        attribution: WyomingInfo.Attribution,
        version: String
    ) -> [WyomingInfo.AsrProgram] {
        guard !locales.isEmpty else { return [] }
        let model = WyomingInfo.AsrModel(
            name: asrModelName,
            description: "Apple on-device speech recognition",
            attribution: attribution,
            installed: true,
            version: version,
            languages: locales.map(\.identifier)
        )
        return [WyomingInfo.AsrProgram(
            name: deviceName,
            description: "Speech-to-text on \(deviceName)",
            attribution: attribution,
            installed: true,
            version: version,
            models: [model]
        )]
    }

    private static func ttsPrograms(
        voices: [OnDeviceVoice],
        deviceName: String,
        attribution: WyomingInfo.Attribution,
        version: String
    ) -> [WyomingInfo.TtsProgram] {
        guard !voices.isEmpty else { return [] }
        let ttsVoices = voices.map { voice in
            WyomingInfo.TtsVoice(
                name: voice.identifier,
                description: voice.name,
                attribution: attribution,
                installed: true,
                version: version,
                languages: [voice.language]
            )
        }
        return [WyomingInfo.TtsProgram(
            name: deviceName,
            description: "Text-to-speech on \(deviceName)",
            attribution: attribution,
            installed: true,
            version: version,
            voices: ttsVoices
        )]
    }
}
