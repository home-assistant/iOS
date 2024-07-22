import Foundation
import Improv_iOS

extension WebViewExternalMessageHandler {
    static func build() -> WebViewExternalMessageHandler {
        WebViewExternalMessageHandler(
            improvManager: ImprovManager.shared,
            localNotificationDispatcher: LocalNotificationDispatcher()
        )
    }
}
