import Shared
import SwiftUI
import UserNotifications
import WatchKit

final class DynamicNotificationHostingController: WKUserNotificationHostingController<DynamicNotificationView> {
    private let viewModel = DynamicNotificationViewModel()

    override var body: DynamicNotificationView {
        DynamicNotificationView(viewModel: viewModel)
    }

    override func didReceive(_ notification: UNNotification) {
        super.didReceive(notification)

        // Keep parity with existing controller: set actions if available
        notificationActions = notification.request.content.userInfoActions

        guard let server = Current.servers.server(for: notification.request.content) else {
            viewModel.errorMessage = "No server available to handle notification."
            viewModel.isLoading = false
            return
        }

        guard let api = Current.api(for: server) else {
            viewModel.errorMessage = "No API available to handle notification."
            viewModel.isLoading = false
            return
        }

        viewModel.configure(from: notification, api: api)
    }

    override func didDeactivate() {
        super.didDeactivate()
        viewModel.stop()
    }
}
