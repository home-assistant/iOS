import MobileCoreServices
import PromiseKit
import Shared
import UIKit
import UserNotifications
import UserNotificationsUI

class PlayerAttachmentViewController: UIViewController, NotificationCategory {
    enum PlayerAttachmentError: Error {
        case noAttachment
    }

    let api: HomeAssistantAPI
    let attachmentURL: URL
    let needsEndSecurityScoped: Bool

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        guard let attachmentURL = attachmentURL else {
            throw PlayerAttachmentError.noAttachment
        }

        self.needsEndSecurityScoped = attachmentURL.startAccessingSecurityScopedResource()

        if Current.isCatalyst,
           attachmentURL.isFileURL,
           !FileManager.default.isReadableFile(atPath: attachmentURL.path) {
            // if it's a file URL, on macOS we may not have access to the attachment on disk, so make sure
            // FB9638431
            throw PlayerAttachmentError.noAttachment
        }

        self.api = api
        self.attachmentURL = attachmentURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if needsEndSecurityScoped {
            videoViewController?.url.stopAccessingSecurityScopedResource()
        }
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

    func start() -> Promise<Void> {
        let controller = with(CameraStreamHLSViewController(api: api, url: attachmentURL)) {
            var lastState: CameraStreamHandlerState?
            $0.didUpdateState = { [extensionContext] state in
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
