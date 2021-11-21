import Foundation
import PromiseKit
import Shared
import UIKit
import UserNotificationsUI

class NotificationErrorViewController: UIViewController, NotificationCategory {
    let label = UILabel()

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        fatalError("not meant to be used in the list of potentials, just directly set")
    }

    init(error: Error) {
        super.init(nibName: nil, bundle: nil)
        label.text = error.localizedDescription
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        label.numberOfLines = 0
        label.textAlignment = .center

        if #available(iOS 13, *) {
            label.textColor = .systemRed
        } else {
            label.textColor = .red
        }

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
