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

extension CameraStreamHandler {
    static func aspectRatioConstraint(on view: UIView, size: CGSize) -> NSLayoutConstraint? {
        guard size.height > 0 else {
            return nil
        }

        let ratio = size.width / size.height
        return view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: ratio)
    }
}
