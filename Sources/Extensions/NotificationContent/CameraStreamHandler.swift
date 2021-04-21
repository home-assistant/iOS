import Foundation
import PromiseKit
import Shared

enum CameraStreamHandlerState {
    case playing
    case paused
}

protocol CameraStreamHandler: AnyObject {
    init(api: HomeAssistantAPI, response: StreamCameraResponse) throws
    var didUpdateState: (CameraStreamHandlerState) -> Void { get set }
    var promise: Promise<Void> { get }
    func pause()
    func play()
}
