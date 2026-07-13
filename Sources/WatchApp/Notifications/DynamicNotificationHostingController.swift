import Shared
import SwiftUI
import UserNotifications
import WatchKit

final class DynamicNotificationHostingController: WKUserNotificationHostingController<DynamicNotificationView> {
    private let viewModel = DynamicNotificationViewModel()

    override var body: DynamicNotificationView {
        DynamicNotificationView(viewModel: viewModel)
    }

    override func willActivate() {
        super.willActivate()
        viewModel.resume()
    }

    override func didDeactivate() {
        super.didDeactivate()
        viewModel.pause()
    }

    override func didReceive(_ notification: UNNotification) {
        notificationActions = notification.request.content.userInfoActions
        viewModel.didReceive(notification)
    }

    override func suggestionsForResponseToAction(
        withIdentifier identifier: String,
        for notification: UNNotification,
        inputLanguage: String
    ) -> [String] {
        // if not implemented, this returns `nil` by default, which causes it to not prompt
        // last tested: watchOS 7.5
        []
    }
}
