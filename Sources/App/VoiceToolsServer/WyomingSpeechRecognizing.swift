import AVFoundation
import Foundation

/// The recogniser a `WyomingSpeechRecognitionSession` drives, reduced to what the session needs.
///
/// A protocol rather than `SFSpeechRecognizer` directly because the session's own behaviour — which
/// transcript wins, what a failure after the audio ended means, answering the client exactly once —
/// is worth testing, and a real recogniser cannot be created without speech authorisation, which no
/// test runner has.
@MainActor
protocol WyomingSpeechRecognizing: AnyObject {
    /// Begins recognising, reporting each transcript as it improves and `isFinal` on the last one.
    /// A recogniser reports at most one failure, and nothing after it.
    func start(
        onTranscript: @escaping (String, Bool) -> Void,
        onFailure: @escaping (Error) -> Void
    )
    func append(_ buffer: AVAudioPCMBuffer)
    /// Tells the recogniser no more audio is coming, which is what makes it produce a final result.
    func endAudio()
    func cancel()
}
