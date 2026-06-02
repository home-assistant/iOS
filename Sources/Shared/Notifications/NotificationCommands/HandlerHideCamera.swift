#if os(iOS)
import Foundation
import PromiseKit

struct HandlerHideCamera: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Promise<Void> { seal in
            let postNotification = {
                NotificationCenter.default.post(
                    name: NotificationCommandManager.didReceiveHideCameraNotification,
                    object: nil
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
