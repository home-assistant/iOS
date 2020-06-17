import Foundation
import UIKit
import PromiseKit
import UserNotificationsUI

class NotificationErrorViewController: UIViewController, NotificationCategory {
    let label = UILabel()

    init(error: Error) {
        super.init(nibName: nil, bundle: nil)
        label.text = error.localizedDescription
    }

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
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func didReceive(notification: UNNotification, extensionContext: NSExtensionContext?) -> Promise<Void> {
        .value(())
    }
    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { .none }
    var mediaPlayPauseButtonFrame: CGRect?
    var mediaPlayPauseButtonTintColor: UIColor?
    func mediaPlay() {}
    func mediaPause() {}
}
