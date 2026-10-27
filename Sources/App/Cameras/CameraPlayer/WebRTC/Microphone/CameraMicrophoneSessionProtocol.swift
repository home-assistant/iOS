import Foundation

protocol CameraMicrophoneSessionProtocol: AnyObject {
    var cameraEntityId: String { get }
    var sessionId: String? { get }
    var isConnected: Bool { get }
    var onEnd: ((CameraMicrophoneError) -> Void)? { get set }
    func start(completion: @escaping (Result<String, CameraMicrophoneError>) -> Void)
    func stop()
    /// Pauses or resumes sending the microphone on a connected session, keeping the connection up.
    func setMicrophoneEnabled(_ enabled: Bool)
}
