import Foundation

protocol MicrophoneRecordingSessionProtocol: AnyObject {
    var sessionId: String { get }
    var isRecording: Bool { get }
    /// Called when the session stops recording on its own, never after `stop`, `finish` or `discard`.
    var onEnd: ((MicrophoneRecordingStopReason) -> Void)? { get set }
    func start(completion: @escaping (Result<String, MicrophoneRecordingError>) -> Void)
    /// Stops recording if it still is, keeping the recording for `finish`.
    func stop()
    /// Stops recording if it still is, and hands over the recording, which the session then forgets.
    func finish(completion: @escaping (Result<MicrophoneRecording, MicrophoneRecordingError>) -> Void)
    /// Stops recording if it still is, and throws the recording away.
    func discard()
}
