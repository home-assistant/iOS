import Alamofire
import KeychainAccess
import MBProgressHUD
import ObjectMapper
import PromiseKit
import Shared
import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    var activeViewController: (UIViewController & NotificationCategory)? {
        willSet {
            activeViewController?.willMove(toParent: nil)
            newValue.flatMap { addChild($0) }
        }
        didSet {
            oldValue?.view.removeFromSuperview()
            oldValue?.removeFromParent()

            if let viewController = activeViewController {
                view.addSubview(viewController.view)
                viewController.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                    viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])

                viewController.didMove(toParent: self)
            } else {
                // 0 doesn't adjust size, must be a > check
                preferredContentSize.height = .leastNonzeroMagnitude
            }
        }
    }

    private static var possibleControllers: [(UIViewController & NotificationCategory).Type] { [
        CameraViewController.self,
        MapViewController.self,
        ImageAttachmentViewController.self,
        PlayerAttachmentViewController.self,
    ] }

    private func viewController(
        for notification: UNNotification,
        api: HomeAssistantAPI,
        attachmentURL: URL?,
        allowDownloads: Bool = true
    ) -> Guarantee<(UIViewController & NotificationCategory)?> {
        // Try based on current info (e.g. entity_id or attached via service extension)

        for controllerType in Self.possibleControllers {
            do {
                let controller = try controllerType.init(
                    api: api,
                    notification: notification,
                    attachmentURL: attachmentURL
                )
                return .value(controller)
            } catch {
                // not valid
            }
        }

        // Try to grab the attachments, in case they failed or were lazy
        let shouldDownload: Bool

        if Current.isCatalyst {
            // catalyst doesn't have access to the system container for the builtin attachments
            // however, it _also_ shows the system preview image in all cases, so we don't need to for that too
            shouldDownload = attachmentURL == nil
        } else {
            shouldDownload = true
        }

        if allowDownloads, shouldDownload {
            return firstly {
                // potential future optimization: feed the url into e.g. the AVPlayer instance.
                // not super straightforward because authentication headers may be needed.
                Current.notificationAttachmentManager.downloadAttachment(from: notification.request.content, api: api)
            }.then { [self] url in
                viewController(for: notification, api: api, attachmentURL: url, allowDownloads: false)
            }.recover { _ in
                .value(nil)
            }
        } else {
            return .value(nil)
        }
    }

    func didReceive(_ notification: UNNotification) {
        let catID = notification.request.content.categoryIdentifier.lowercased()
        Current.Log.verbose("Received a notif with userInfo \(notification.request.content.userInfo)")

        guard let server = Current.servers.server(for: notification.request.content) else {
            Current.Log.info("ignoring push when unable to find server")
            return
        }

        let api = Current.api(for: server)

        // we only do it for 'dynamic' or unconfigured existing categories, so we don't stomp old configs
        if catID == "dynamic" || extensionContext?.notificationActions.isEmpty == true {
            extensionContext?.notificationActions = notification.request.content.userInfoActions
        }

        activeViewController = NotificationLoadingViewController()

        var hud: MBProgressHUD?

        viewController(
            for: notification,
            api: api,
            attachmentURL: notification.request.content.attachments.first?.url
        ).then { [weak self] controller -> Promise<Void> in
            self?.activeViewController = controller

            guard let controller = controller else {
                return .value(())
            }

            if controller.mediaPlayPauseButtonType == .none, let view = self?.view {
                // don't show the HUD for a screen that has pause/play because it already acts like a loading indicator
                hud = {
                    let hud = MBProgressHUD.showAdded(to: view, animated: true)
                    hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset + 50)
                    return hud
                }()
            }

            return controller.start()
        }.ensure {
            hud?.hide(animated: true)
        }.catch { [weak self] error in
            Current.Log.error("finally failed: \(error)")
            self?.activeViewController = NotificationErrorViewController(error: error)
        }
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType {
        activeViewController?.mediaPlayPauseButtonType ?? .none
    }

    var mediaPlayPauseButtonFrame: CGRect {
        CGRect(
            x: view.bounds.width / 2.0 - 22,
            y: view.bounds.height / 2.0 - 22,
            width: 44,
            height: 44
        )
    }

    public func mediaPlay() {
        activeViewController?.mediaPlay()
    }

    public func mediaPause() {
        activeViewController?.mediaPause()
    }
}

protocol NotificationCategory: NSObjectProtocol {
    init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws
    func start() -> Promise<Void>

    // Implementing this method and returning a button type other that "None" will
    // make the notification attempt to draw a play/pause button correctly styled
    // for that type.
    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { get }

    // Implementing this method and returning a non-empty frame will make
    // the notification draw a button that allows the user to play and pause
    // media content embedded in the notification.
    var mediaPlayPauseButtonFrame: CGRect? { get }

    // Called when the user taps the play or pause button.
    func mediaPlay()
    func mediaPause()
}
