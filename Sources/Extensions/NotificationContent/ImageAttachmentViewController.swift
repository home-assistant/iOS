import MobileCoreServices
import PromiseKit
import Shared
import UIKit
import UserNotifications
import UserNotificationsUI

class ImageAttachmentViewController: UIViewController, NotificationCategory {
    let imageView = with(UIImageView()) {
        $0.contentMode = .scaleAspectFit
    }

    enum ImageAttachmentError: Error {
        case noAttachment
        case notImage
        case securityFailure
        case imageDecodeFailure
    }

    private var aspectRatioConstraint: NSLayoutConstraint? {
        willSet {
            aspectRatioConstraint?.isActive = false
        }
        didSet {
            aspectRatioConstraint?.isActive = true
        }
    }

    private var lastAttachmentURL: URL? {
        didSet {
            oldValue?.stopAccessingSecurityScopedResource()
        }
    }

    deinit {
        lastAttachmentURL?.stopAccessingSecurityScopedResource()
    }

    func didReceive(
        notification: UNNotification,
        extensionContext: NSExtensionContext?
    ) throws -> Promise<Void> {
        guard let attachment = notification.request.content.attachments.first else {
            throw ImageAttachmentError.noAttachment
        }

        guard attachment.url.startAccessingSecurityScopedResource() else {
            throw ImageAttachmentError.securityFailure
        }

        // rather than hard-coding an acceptable list of UTTypes it's probably easier to just try decoding
        // https://developer.apple.com/documentation/usernotifications/unnotificationattachment
        // has the full list of what is advertised - at time of writing (iOS 14.5) it's jpeg, gif and png
        // but iOS 14 also supports webp, so who knows if it'll be added silently or not

        guard let image = UIImage(contentsOfFile: attachment.url.path) else {
            attachment.url.stopAccessingSecurityScopedResource()
            throw ImageAttachmentError.imageDecodeFailure
        }

        imageView.image = image
        lastAttachmentURL = attachment.url
        aspectRatioConstraint = NSLayoutConstraint.aspectRatioConstraint(on: imageView, size: image.size)

        return .value(())
    }

    override func loadView() {
        class UnanimatingView: UIView {
            override func layoutSubviews() {
                // avoids the image view sizing up from nothing when initially displaying
                // since we don't control our own view's expansion, we need to disable animation at our level
                UIView.performWithoutAnimation {
                    super.layoutSubviews()
                }
            }
        }

        view = UnanimatingView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { .none }
    var mediaPlayPauseButtonFrame: CGRect?
    func mediaPlay() {}
    func mediaPause() {}
}
