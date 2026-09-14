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

        // watchOS never hands a `UNTextInputNotificationResponse` back to the app for a forwarded
        // notification, so a text-input action put in `notificationActions` shows the reply screen
        // and then silently drops whatever the user wrote — no event ever reaches Home Assistant.
        // Those actions are therefore kept out of the system's list and rendered by the long look
        // itself, which collects the reply and fires the event directly. Every other action still
        // goes through the system, including the snooze presets `userInfoActions` falls back to
        // when the payload carries no actions of its own.
        if payloadActions.isEmpty {
            notificationActions = notification.request.content.userInfoActions
        } else {
            notificationActions = payloadActions.filter { !$0.textInput }.map(\.action)
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

        viewModel.didReceive(notification, textInputActions: payloadActions.filter(\.textInput))
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
