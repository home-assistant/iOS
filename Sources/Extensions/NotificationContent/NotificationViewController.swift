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
        for notification: UNNotification
    ) -> (UIViewController & NotificationCategory, Promise<Void>)? {
        for controllerType in Self.possibleControllers {
            do {
                let controller = controllerType.init()
                let promise = try controller.didReceive(notification: notification, extensionContext: extensionContext)
                return (controller, promise)
            } catch {
                // not valid
            }
        }

        return nil
    }

    func didReceive(_ notification: UNNotification) {
        let catID = notification.request.content.categoryIdentifier.lowercased()
        Current.Log.verbose("Received a notif with userInfo \(notification.request.content.userInfo)")

        // we only do it for 'dynamic' or unconfigured existing categories, so we don't stomp old configs
        if catID == "dynamic" || extensionContext?.notificationActions.isEmpty == true {
            extensionContext?.notificationActions = notification.request.content.userInfoActions
        }

        guard let (controller, promise) = viewController(for: notification) else {
            activeViewController = nil
            return
        }

        activeViewController = controller

        let hud: MBProgressHUD? = {
            guard controller.mediaPlayPauseButtonType == .none else {
                // don't show the HUD for a screen that has pause/play because it already acts like a loading indicator
                return nil
            }

            let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
            hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset + 50)
            return hud
        }()

        promise.ensure {
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
    // This will be called to send the notification to be displayed by
    // the extension. If the extension is being displayed and more related
    // notifications arrive (eg. more messages for the same conversation)
    // the same method will be called for each new notification.
    func didReceive(
        notification: UNNotification,
        extensionContext: NSExtensionContext?
    ) throws -> Promise<Void>

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
