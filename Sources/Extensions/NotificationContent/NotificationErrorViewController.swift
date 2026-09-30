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

class NotificationErrorViewController: PlatformViewController, NotificationCategory {
    #if os(macOS)
    let label = NSTextField(wrappingLabelWithString: "")
    #else
    let label = UILabel()
    #endif

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        fatalError("not meant to be used in the list of potentials, just directly set")
    }

    init(error: Error) {
        super.init(nibName: nil, bundle: nil)
        #if os(macOS)
        label.stringValue = error.localizedDescription
        #else
        label.text = error.localizedDescription
        #endif
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
        label.isSelectable = false
        label.alignment = .center
        label.textColor = .systemRed
        // The message wraps to the width the notification has rather than widening the notification.
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        #else
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .systemRed
        #endif

        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
