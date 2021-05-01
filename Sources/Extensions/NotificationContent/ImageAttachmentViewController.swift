import MobileCoreServices
import PromiseKit
import Shared
import UIKit
import UserNotifications
import UserNotificationsUI

class ImageAttachmentViewController: UIViewController, NotificationCategory {
    let attachmentURL: URL
    let needsEndSecurityScoped: Bool
    let image: UIImage
    let imageView = with(UIImageView()) {
        $0.contentMode = .scaleAspectFit
    }

    required init(notification: UNNotification, attachmentURL: URL?) throws {
        guard let attachmentURL = attachmentURL else {
            throw ImageAttachmentError.noAttachment
        }

        self.needsEndSecurityScoped = attachmentURL.startAccessingSecurityScopedResource()

        // rather than hard-coding an acceptable list of UTTypes it's probably easier to just try decoding
        // https://developer.apple.com/documentation/usernotifications/unnotificationattachment
        // has the full list of what is advertised - at time of writing (iOS 14.5) it's jpeg, gif and png
        // but iOS 14 also supports webp, so who knows if it'll be added silently or not

        guard let image = UIImage(contentsOfFile: attachmentURL.path) else {
            attachmentURL.stopAccessingSecurityScopedResource()
            throw ImageAttachmentError.imageDecodeFailure
        }

        self.image = image
        self.attachmentURL = attachmentURL
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if needsEndSecurityScoped {
            attachmentURL.stopAccessingSecurityScopedResource()
        }
    }

    enum ImageAttachmentError: Error {
        case noAttachment
        case notImage
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

    func start() -> Promise<Void> {
        imageView.image = image
        lastAttachmentURL = attachmentURL
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
