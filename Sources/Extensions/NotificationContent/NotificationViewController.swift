import Alamofire
import KeychainAccess
import PromiseKit
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UserNotifications
import UserNotificationsUI

class NotificationViewController: PlatformViewController, UNNotificationContentExtension {
    var activeViewController: (PlatformViewController & NotificationCategory)? {
        willSet {
            #if !os(macOS)
            activeViewController?.willMove(toParent: nil)
            #endif
            newValue.flatMap { addChild($0) }
        }
        didSet {
            oldValue?.view.removeFromSuperview()
            oldValue?.removeFromParent()

            if let viewController = activeViewController {
                view.addSubview(viewController.view)
                viewController.view.translatesAutoresizingMaskIntoConstraints = false
                #if os(macOS)
                // The content decides its own height from its constraints and the notification is told
                // that height through `preferredContentSize`. Until the system applies it the two
                // disagree, so the bottom edge yields rather than fighting the frame the system set.
                let bottom = viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                bottom.priority = .defaultLow
                #else
                let bottom = viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                #endif
                NSLayoutConstraint.activate([
                    viewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                    viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    bottom,
                ])

                #if !os(macOS)
                viewController.didMove(toParent: self)
                #endif
            } else {
                // 0 doesn't adjust size, must be a > check
                preferredContentSize.height = .leastNonzeroMagnitude
            }
        }
    }

    #if os(macOS)
    override func loadView() {
        view = NSView()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updatePreferredContentSize()
    }

    /// Passes the height the content laid itself out to on to the system, which sizes the notification
    /// from `preferredContentSize` rather than from the view's constraints. Only the height matters to
    /// the system; the width is whatever it gave the notification.
    private func updatePreferredContentSize() {
        guard let contentView = activeViewController?.view, view.bounds.width > 0 else {
            return
        }

        let height = contentView.frame.height
        guard abs(preferredContentSize.height - height) > 0.5 else {
            return
        }

        preferredContentSize = CGSize(width: view.bounds.width, height: height)
    }
    #endif

    private static var possibleControllers: [(PlatformViewController & NotificationCategory).Type] { [
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
    ) -> Guarantee<(PlatformViewController & NotificationCategory)?> {
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

        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to handle func didReceive(_ notification: UNNotification)")
            return
        }

        // we only do it for 'dynamic' or unconfigured existing categories, so we don't stomp old configs
        if catID == "dynamic" || extensionContext?.notificationActions.isEmpty == true {
            extensionContext?.notificationActions = notification.request.content.userInfoActions
        }

        activeViewController = NotificationLoadingViewController()

        #if os(macOS)
        var indicator: NSProgressIndicator?
        #else
        var indicator: UIActivityIndicatorView?
        #endif

        viewController(
            for: notification,
            api: api,
            attachmentURL: notification.request.content.attachments.first?.url
        ).then { [weak self] controller -> Promise<Void> in
            self?.activeViewController = controller

            guard let controller else {
                return .value(())
            }

            if controller.mediaPlayPauseButtonType == .none, !controller.hidesSystemLoadingIndicator,
               let view = self?.view {
                // don't show the HUD for a screen that has pause/play because it already acts like a loading indicator
                indicator = {
                    #if os(macOS)
                    let indicator = NSProgressIndicator()
                    indicator.style = .spinning
                    indicator.controlSize = .small
                    indicator.isIndeterminate = true
                    #else
                    let indicator = UIActivityIndicatorView(style: .medium)
                    #endif
                    indicator.translatesAutoresizingMaskIntoConstraints = false
                    view.addSubview(indicator)
                    NSLayoutConstraint.activate([
                        indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                        indicator.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
                    ])
                    #if os(macOS)
                    NSLayoutConstraint.activate([
                        indicator.widthAnchor.constraint(equalToConstant: 16),
                        indicator.heightAnchor.constraint(equalToConstant: 16),
                    ])
                    indicator.startAnimation(nil)
                    #else
                    indicator.startAnimating()
                    #endif
                    return indicator
                }()
            }

            return controller.start()
        }.ensure {
            #if os(macOS)
            indicator?.stopAnimation(nil)
            #else
            indicator?.stopAnimating()
            #endif
            indicator?.removeFromSuperview()
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

    // Return true to suppress the system loading HUD because the controller shows its own indicator.
    var hidesSystemLoadingIndicator: Bool { get }

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

extension NotificationCategory {
    var hidesSystemLoadingIndicator: Bool { false }
}
