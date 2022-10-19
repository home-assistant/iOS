import EMTLoadingIndicator
import Foundation
import PromiseKit
import Shared
import UserNotifications
import WatchKit

class DynamicNotificationController: WKUserNotificationInterfaceController {
    @IBOutlet var loadingImage: WKInterfaceImage!
    @IBOutlet var errorLabel: WKInterfaceLabel!
    @IBOutlet var notificationTitleLabel: WKInterfaceLabel!
    @IBOutlet var notificationSubtitleLabel: WKInterfaceLabel!
    @IBOutlet var notificationAlertLabel: WKInterfaceLabel!
    @IBOutlet var notificationImage: WKInterfaceImage!
    @IBOutlet var notificationVideo: WKInterfaceInlineMovie!
    @IBOutlet var notificationMap: WKInterfaceMap!

    private var loadingIndicator: EMTLoadingIndicator?
    private var activeSubController: NotificationSubController? {
        willSet {
            if activeSubController !== newValue {
                activeSubController?.stop()
            }
        }
        didSet {
            if isActive {
                start()
            }
        }
    }

    private lazy var dynamicElements: NotificationElements = .init(
        image: notificationImage,
        map: notificationMap,
        movie: notificationVideo
    )

    private var isActive: Bool = false {
        didSet {
            if isActive {
                start()
            } else if let subController = activeSubController {
                subController.stop()
            }
        }
    }

    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                if loadingIndicator == nil {
                    loadingIndicator = with(EMTLoadingIndicator(
                        interfaceController: self,
                        interfaceImage: loadingImage,
                        width: 40,
                        height: 40,
                        style: .dot
                    )) {
                        $0.showWait()
                    }
                }
            } else {
                loadingIndicator?.hide()
                loadingImage.setHidden(true)
                loadingIndicator = nil
            }
        }
    }

    override func willActivate() {
        super.willActivate()
        isActive = true
    }

    override func didDeactivate() {
        super.didDeactivate()
        isActive = false
    }

    private func start() {
        guard let subController = activeSubController else { return }

        isLoading = true

        firstly {
            subController.start(with: dynamicElements)
        }.ensure { [self] in
            isLoading = false
        }.catch { [self] error in
            show(error: error)
        }
    }

    private func show(error: Error) {
        errorLabel.setTextColor(.red)
        errorLabel.setTextAndHideIfEmpty(L10n.NotificationService.failedToLoad + "\n" + error.localizedDescription)
    }

    private var possibleSubControllers: [NotificationSubController.Type] { [
        NotificationSubControllerMJPEG.self,
        NotificationSubControllerMap.self,
        NotificationSubControllerMedia.self,
    ] }

    private func subController(for notification: UNNotification, api: HomeAssistantAPI) -> NotificationSubController? {
        for potential in possibleSubControllers {
            if let controller = potential.init(api: api, notification: notification) {
                return controller
            }
        }

        return nil
    }

    private func subController(for url: URL, api: HomeAssistantAPI) -> NotificationSubController? {
        for potential in possibleSubControllers {
            if let controller = potential.init(api: api, url: url) {
                return controller
            }
        }

        return nil
    }

    override func didReceive(_ notification: UNNotification) {
        super.didReceive(notification)

        notificationTitleLabel.setTextAndHideIfEmpty(notification.request.content.title)
        notificationSubtitleLabel.setTextAndHideIfEmpty(notification.request.content.subtitle)
        notificationAlertLabel.setTextAndHideIfEmpty(notification.request.content.body)

        errorLabel.setHidden(true)
        dynamicElements.hide()

        guard let server = Current.servers.server(for: notification.request.content) else {
            return
        }

        let api = Current.api(for: server)
        notificationActions = notification.request.content.userInfoActions

        if let active = subController(for: notification, api: api) {
            activeSubController = active
        } else {
            isLoading = true

            firstly {
                Current.notificationAttachmentManager.downloadAttachment(from: notification.request.content, api: api)
            }.tap { [self] result in
                if case .rejected = result {
                    // we don't stop loading on success 'cause it's just gonna turn it on again
                    isLoading = false
                }
            }.map { [self] url in
                subController(for: url, api: api)
            }.done { [self] controller in
                activeSubController = controller
            }.catch { [self] error in
                Current.Log.info("no attachments downloaded: \(error)")

                if error as? NotificationAttachmentManagerServiceError == .noAttachment {
                    // can make the above != but it doesn't clearly indicate
                } else {
                    show(error: error)
                }
            }
        }
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
