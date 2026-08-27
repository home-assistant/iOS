import Combine
import Foundation
import Shared

@MainActor
final class AssistSettingsViewModel: ObservableObject {
    @Published var configuration: AssistConfiguration

    /// Locales that support on-device speech recognition. Empty until `loadSupportedSTTLocales()`
    /// finishes, and on OS versions without on-device transcription.
    @Published private(set) var supportedSTTLocales: [Locale] = []

    /// Name of the selected text-to-speech voice, falling back to the default-voice label.
    @Published private(set) var selectedVoiceDisplayName = L10n.Assist.Settings.OnDeviceTts.defaultVoice

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.configuration = AssistConfiguration.config

        $configuration
            .dropFirst() // Skip the initial value set in init
            .sink { config in
                config.save()
            }
            .store(in: &cancellables)
    }

    /// Probing the on-device speech locales blocks its caller for close to a second, so the list is
    /// filled in asynchronously instead of being read while the settings view builds.
    func loadSupportedSTTLocales() async {
        // On-device transcription is an iOS 17 feature, so older versions never show the list.
        guard #available(iOS 17.0, *) else { return }
        supportedSTTLocales = await SupportedSpeechLocales.shared.locales()
        selectDefaultSTTLocaleIfNeeded()
    }

    /// Resolving a voice identifier goes through the TextToSpeech daemon, which is too slow for a
    /// view body; the view awaits this whenever the selected identifier changes.
    func loadSelectedVoiceDisplayName() async {
        guard let identifier = configuration.onDeviceTTSVoiceIdentifier else {
            selectedVoiceDisplayName = L10n.Assist.Settings.OnDeviceTts.defaultVoice
            return
        }
        let voice = await OnDeviceVoiceCatalog.voice(withIdentifier: identifier)
        selectedVoiceDisplayName = voice?.name ?? L10n.Assist.Settings.OnDeviceTts.defaultVoice
    }

    /// Falls back to a supported locale when on-device transcription is enabled but the stored
    /// locale is unset or not supported. Does nothing until the supported locales are known.
    func selectDefaultSTTLocaleIfNeeded() {
        guard configuration.enableOnDeviceSTT, !supportedSTTLocales.isEmpty else { return }
        let supportedIdentifiers = Set(supportedSTTLocales.map(\.identifier))
        guard !supportedIdentifiers.contains(configuration.onDeviceSTTLocaleIdentifier ?? "") else { return }
        configuration.onDeviceSTTLocaleIdentifier = supportedSTTLocales.first?.identifier
    }
}
