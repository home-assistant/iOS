import MobileCoreServices
import PromiseKit
import Shared
import UIKit
import UserNotifications
import UserNotificationsUI
import WebKit

class ImageAttachmentViewController: UIViewController, NotificationCategory {
    let attachmentURL: URL
    let needsEndSecurityScoped: Bool
    let image: UIImage
    let imageData: Data
    let imageUTI: CFString

    enum ImageViewType {
        case imageView(UIImageView)
        case webView(WKWebView)

        var view: UIView {
            switch self {
            case let .imageView(imageView): return imageView
            case let .webView(webView): return webView
            }
        }
    }

    let visibleView: ImageViewType

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        guard let attachmentURL = attachmentURL else {
            throw ImageAttachmentError.noAttachment
        }

        self.needsEndSecurityScoped = attachmentURL.startAccessingSecurityScopedResource()

        // rather than hard-coding an acceptable list of UTTypes it's probably easier to just try decoding
        // https://developer.apple.com/documentation/usernotifications/unnotificationattachment
        // has the full list of what is advertised - at time of writing (iOS 14.5) it's jpeg, gif and png
        // but iOS 14 also supports webp, so who knows if it'll be added silently or not

        do {
            let data = try Data(contentsOf: attachmentURL, options: .alwaysMapped)
            guard let image = UIImage(data: data) else {
                throw ImageAttachmentError.imageDecodeFailure
            }
            self.image = image
            self.imageData = data

            if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
               let uti = CGImageSourceGetType(imageSource) {
                self.imageUTI = uti
            } else {
                // can't figure out, just assume JPEG
                self.imageUTI = kUTTypeJPEG
            }

            if UTTypeConformsTo(imageUTI, kUTTypeGIF) {
                // use a WebView for gif so we can animate without pulling in a third party library
                let config = with(WKWebViewConfiguration()) {
                    $0.userContentController = with(WKUserContentController()) {
                        // we can't use `loadHTMLString` with `<img>` inside to do styling because the webview can't get
                        // the security scoped file if loaded by the service extension so we need to load data directly
                        $0.addUserScript(WKUserScript(source: """
                            var style = document.createElement('style');
                            style.innerHTML = `
                                img { width: 100%; height: 100%; }
                            `;
                            document.head.appendChild(style);
                        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
                    }
                }

                self.visibleView = .webView(with(WKWebView(frame: .zero, configuration: config)) {
                    $0.scrollView.isScrollEnabled = false
                    $0.isOpaque = false
                    $0.backgroundColor = .clear
                    $0.scrollView.backgroundColor = .clear
                })
            } else {
                self.visibleView = .imageView(with(UIImageView()) {
                    $0.contentMode = .scaleAspectFit
                })
            }

        } catch {
            attachmentURL.stopAccessingSecurityScopedResource()
            throw error
        }

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
        lastAttachmentURL = attachmentURL

        switch visibleView {
        case let .webView(webView):
            let mime = UTTypeCopyPreferredTagWithClass(imageUTI, kUTTagClassMIMEType)?.takeRetainedValue() as String?
            webView.load(
                imageData,
                mimeType: mime ?? "image/gif",
                characterEncodingName: "UTF-8",
                baseURL: attachmentURL
            )
        case let .imageView(imageView):
            imageView.image = image
        }

        aspectRatioConstraint = NSLayoutConstraint.aspectRatioConstraint(on: visibleView.view, size: image.size)

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

        let subview = visibleView.view
        view.addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: view.topAnchor),
            subview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            subview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { .none }
    var mediaPlayPauseButtonFrame: CGRect?
    func mediaPlay() {}
    func mediaPause() {}
}
