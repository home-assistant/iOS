import Foundation

protocol CameraMicrophoneSessionProtocol: AnyObject {
    var cameraEntityId: String { get }
    var isConnected: Bool { get }
    var onEnd: ((CameraMicrophoneError) -> Void)? { get set }
    func start(completion: @escaping (Result<Void, CameraMicrophoneError>) -> Void)
    func stop()
}
