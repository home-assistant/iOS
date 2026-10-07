import Foundation

/// The stages of an Assist pipeline the server runs for one request, decided from where the user
/// wants speech handled and from what the pipeline can do.
///
/// The backend validates a run against its pipeline before emitting anything: a run that ends at
/// `tts` on a pipeline without a text-to-speech engine, or starts at `stt` on one without a
/// speech-to-text engine, is rejected outright. Asking only for what the pipeline has keeps a
/// text-only pipeline usable by voice when the transcription happens on device.
public struct AssistRunStages: Equatable {
    /// The run starts at `stt` and the server transcribes the audio; otherwise it starts at `intent`
    /// with text.
    public let startsWithSpeechToText: Bool
    /// The run ends at `tts` and the server synthesizes the reply; otherwise it ends at `intent`.
    public let endsWithTextToSpeech: Bool

    /// - Parameters:
    ///   - pipeline: The pipeline the run targets, or nil while its capabilities are unknown — the
    ///     request is then sent as asked and the backend has the final word.
    ///   - listening: Who transcribes a spoken request, or nil for a typed one.
    ///   - speaking: Who speaks the reply, or nil when it is not spoken.
    /// - Returns: nil when the request needs the server to transcribe audio and the pipeline has no
    ///   speech-to-text engine.
    public init?(pipeline: Pipeline?, listening: AssistSpeechEngine?, speaking: AssistSpeechEngine?) {
        let startsWithSpeechToText = listening == .server
        if startsWithSpeechToText, pipeline?.supportsSpeechToText == false {
            return nil
        }
        self.startsWithSpeechToText = startsWithSpeechToText
        // A pipeline without text-to-speech still answers in text, so the reply is only left unspoken.
        self.endsWithTextToSpeech = speaking == .server && pipeline?.supportsTextToSpeech != false
    }
}
