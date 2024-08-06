import Foundation
import Improv_iOS
import Shared

extension WebViewExternalMessageHandler {
    static func build() -> WebViewExternalMessageHandler {
        WebViewExternalMessageHandler(
            improvManager: ImprovManager.shared,
            localNotificationDispatcher: LocalNotificationDispatcher()
        )
    }
}
