import MobileCoreServices
import PromiseKit
import Shared
import UIKit
import UserNotifications
import UserNotificationsUI

class PlayerAttachmentViewController: UIViewController, NotificationCategory {
    enum PlayerAttachmentError: Error {
        case noAttachment
        case securityFailure
    }

    var videoViewController: CameraStreamHLSViewController? {
        willSet {
            videoViewController?.url.stopAccessingSecurityScopedResource()
            videoViewController?.willMove(toParent: nil)
            newValue.flatMap { addChild($0) }
        }
        didSet {
            oldValue?.view.removeFromSuperview()
            oldValue?.removeFromParent()

            if let videoViewController = videoViewController {
                view.addSubview(videoViewController.view)
                videoViewController.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    videoViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
                    videoViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    videoViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    videoViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])
                
                videoViewController.didMove(toParent: self)
            }
        }
    }

    deinit {
        videoViewController?.url.stopAccessingSecurityScopedResource()
    }

    func didReceive(notification: UNNotification, extensionContext: NSExtensionContext?) throws -> Promise<Void> {
        guard let attachment = notification.request.content.attachments.first else {
            throw PlayerAttachmentError.noAttachment
        }

        guard attachment.url.startAccessingSecurityScopedResource() else {
            throw PlayerAttachmentError.securityFailure
        }

        let controller = with(CameraStreamHLSViewController(url: attachment.url)) {
            var lastState: CameraStreamHandlerState?
            $0.didUpdateState = { state in
                guard lastState != state else {
                    return
                }

                switch state {
                case .playing:
                    // if this happens too fast (which happens for local files) the extension context ignores it
                    // so trigger a short delay as well
                    extensionContext?.mediaPlayingStarted()
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                        if lastState == .playing {
                            extensionContext?.mediaPlayingStarted()
                        }
                    }
                case .paused:
                    extensionContext?.mediaPlayingPaused()
                }

                lastState = state
            }
        }
        videoViewController = controller
        return controller.promise
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { .overlay }
    var mediaPlayPauseButtonFrame: CGRect? { nil }

    func mediaPlay() {
        videoViewController?.play()
    }

    func mediaPause() {
        videoViewController?.pause()
    }
}
