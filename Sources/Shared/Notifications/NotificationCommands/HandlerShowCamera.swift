#if os(iOS)
import Foundation
import PromiseKit

private enum ShowCameraError: Error {
    case invalidEntityId
}

struct HandlerShowCamera: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard let entityId = payload["entity_id"] as? String, entityId.hasPrefix("camera.") else {
            Current.Log.error("Received show_camera push command without a valid camera entity_id")
            return Promise(error: ShowCameraError.invalidEntityId)
        }

        return Promise<Void> { seal in
            let postNotification = {
                NotificationCenter.default.post(
                    name: NotificationCommandManager.didReceiveShowCameraNotification,
                    object: nil,
                    userInfo: payload.reduce(into: [AnyHashable: Any]()) { result, element in
                        result[element.key] = element.value
                    }
                )
                seal.fulfill(())
            }

            if Thread.isMainThread {
                postNotification()
            } else {
                DispatchQueue.main.async(execute: postNotification)
            }
        }
    }
}
#endif
