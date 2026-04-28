import Eureka
import PromiseKit
import RealmSwift
import Shared
import UIKit

enum SettingsDetailsGroup: String {
    case display
}

class SettingsDetailViewController: HAFormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var detailGroup: SettingsDetailsGroup = .display

    var doneButton: Bool = false

    private let realm = Current.realm()
    private var notificationTokens: [NotificationToken] = []
    private var notificationCenterTokens: [AnyObject] = []

    deinit {
        notificationCenterTokens.forEach(NotificationCenter.default.removeObserver)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if doneButton {
            navigationItem.rightBarButtonItem = nil
            doneButton = false
        }
        onDismissCallback?(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        if doneButton {
            let closeSelector = #selector(SettingsDetailViewController.closeSettingsDetailView(_:))
            let doneButton = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: closeSelector
            )
            navigationItem.setRightBarButton(doneButton, animated: true)
        }

        switch detailGroup {
        default:
            Current.Log.warning("Something went wrong, no settings detail group named \(detailGroup)")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        // Log in case user is running with internal URL set but not configured local access
        for server in Current.servers.all {
            if server.info.connection.hasInternalURLSet,
               server.info.connection.internalSSIDs?.isEmpty ?? true,
               server.info.connection.internalHardwareAddresses?.isEmpty ?? true {
                let message =
                    "Server \(server.info.name) - Internal URL set but no internal SSIDs or hardware addresses set"
                Current.Log.error(message)
                Current.clientEventStore.addEvent(.init(text: message, type: .settings))
            }
        }
    }

    @objc func closeSettingsDetailView(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
}
