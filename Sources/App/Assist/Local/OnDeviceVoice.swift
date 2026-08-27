import AVFoundation
import Foundation

/// An installed text-to-speech voice, reduced to the values the UI needs.
///
/// `AVSpeechSynthesisVoice` is a reference type backed by the TextToSpeech daemon, so voice lists
/// are converted into these values off the main thread by `OnDeviceVoiceCatalog` and the UI never
/// touches the framework objects while it builds a view.
struct OnDeviceVoice: Identifiable, Hashable, Sendable {
    let identifier: String
    let name: String
    /// BCP 47 language tag of the voice, e.g. `en-US`.
    let language: String
    let quality: AVSpeechSynthesisVoiceQuality

    var id: String { identifier }

    init(_ voice: AVSpeechSynthesisVoice) {
        self.identifier = voice.identifier
        self.name = voice.name
        self.language = voice.language
        self.quality = voice.quality
    }
}
