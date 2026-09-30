import Foundation
import PromiseKit
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UserNotifications
import UserNotificationsUI

class NotificationLoadingViewController: PlatformViewController, NotificationCategory {
    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        super.init(nibName: nil, bundle: nil)
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if os(macOS)
    override func loadView() {
        view = NSView()
    }
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        #if os(macOS)
        let activityIndicator = NSProgressIndicator()
        activityIndicator.style = .spinning
        activityIndicator.controlSize = .small
        activityIndicator.isIndeterminate = true

        // The spinner sets the height of the notification while it loads, so it is pinned top to bottom
        // and centred rather than stretched across the width.
        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.topAnchor.constraint(equalTo: view.topAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.widthAnchor.constraint(equalToConstant: 16),
            activityIndicator.heightAnchor.constraint(equalToConstant: 16),
        ])

        activityIndicator.startAnimation(nil)
        #else
        let activityIndicator: UIActivityIndicatorView

        activityIndicator = UIActivityIndicatorView(style: .medium)

        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.topAnchor.constraint(equalTo: view.topAnchor),
            activityIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        activityIndicator.startAnimating()
        #endif
    }

    func start() -> Promise<Void> {
        .value(())
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { .none }
    var mediaPlayPauseButtonFrame: CGRect?
    var mediaPlayPauseButtonTintColor: UIColor?
    func mediaPlay() {}
    func mediaPause() {}
}
