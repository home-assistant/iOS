import Foundation

protocol CameraMicrophoneSessionProtocol: AnyObject {
    var cameraEntityId: String { get }
    var sessionId: String? { get }
    var isConnected: Bool { get }
    var onEnd: ((CameraMicrophoneError) -> Void)? { get set }
    func start(completion: @escaping (Result<String, CameraMicrophoneError>) -> Void)
    func stop()
    func setMicrophoneEnabled(_ enabled: Bool)
}
