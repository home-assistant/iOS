import AVFoundation
import Foundation

/// Reads the installed text-to-speech voices off the main thread.
///
/// `AVSpeechSynthesisVoice.speechVoices()` and `AVSpeechSynthesisVoice(identifier:)` wait on the
/// TextToSpeech daemon and can block their caller for over a hundred milliseconds — enough to hang
/// the run loop when a view body resolves the selected voice — so every lookup goes through here.
enum OnDeviceVoiceCatalog {
    /// Every installed voice, sorted by name.
    static func voices() async -> [OnDeviceVoice] {
        await Task.detached(priority: .userInitiated) {
            AVSpeechSynthesisVoice.speechVoices()
                .map(OnDeviceVoice.init)
                .sorted { $0.name < $1.name }
        }.value
    }

    /// The installed voice with the given identifier, or `nil` when it is no longer installed.
    static func voice(withIdentifier identifier: String) async -> OnDeviceVoice? {
        let allVoices = await voices()
        return allVoices.first { $0.identifier == identifier }
    }
}
