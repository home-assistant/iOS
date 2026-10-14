import Foundation

protocol MicrophoneAudioRecorderProtocol: AnyObject {
    /// Called on the main queue when recording stops by itself, with whether the file was written.
    var onFinish: ((_ successfully: Bool) -> Void)? { get set }
    func record(forDuration duration: TimeInterval) -> Bool
    func stop()
}
