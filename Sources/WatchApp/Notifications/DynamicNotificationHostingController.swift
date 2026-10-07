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
        let payloadActions = notification.request.content.userInfoPayloadActions
        let split = NotificationActionSplit(payloadActions: payloadActions)

        // The actions `split` hands back to the app are the ones watchOS would drop the reply for;
        // everything else stays with the system, including the snooze presets `userInfoActions`
        // falls back to when the payload carries no actions of its own.
        if payloadActions.isEmpty {
            notificationActions = notification.request.content.userInfoActions
        } else {
            notificationActions = split.systemHandled.map(\.action)
        }

        viewModel.presentTextInput = { [weak self] completion in
            guard let self else {
                completion(nil)
                return
            }

            presentTextInputController(withSuggestions: nil, allowedInputMode: .plain) { results in
                completion(results?.compactMap { $0 as? String }.first)
            }
        }

        viewModel.didReceive(notification, textInputActions: split.appHandled)
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
