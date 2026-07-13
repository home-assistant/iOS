import Foundation
import PromiseKit
import Shared

enum CameraStreamHandlerState {
    case playing
    case paused
}

protocol CameraStreamHandler: AnyObject {
    init(api: HomeAssistantAPI, response: StreamCameraResponse, baseURL: URL) throws
    var didUpdateState: (CameraStreamHandlerState) -> Void { get set }
    var promise: Promise<Void> { get }
    func pause()
    func play()

    var hasAudio: Bool { get }
    var isMuted: Bool { get }
    func setMuted(_ muted: Bool)
}

extension CameraStreamHandler {
    var hasAudio: Bool { false }
    var isMuted: Bool { true }
    func setMuted(_ muted: Bool) {}
}
