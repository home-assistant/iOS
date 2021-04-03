import Shared
import UIKit

class PermissionsViewController: UIViewController, PermissionViewChangeDelegate {
    var instance: DiscoveredHomeAssistant!
    var connectionInfo: ConnectionInfo!

    @IBOutlet var continueButton: UIButton!
    @IBOutlet var locationPermissionView: PermissionLineItemView!
    @IBOutlet var motionPermissionView: PermissionLineItemView!
    @IBOutlet var notificationsPermissionView: PermissionLineItemView!
    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(continueButton)
        }

        locationPermissionView.delegate = self
        locationPermissionView.permission.updateInitial()

        motionPermissionView.delegate = self
        motionPermissionView.permission.updateInitial()
        motionPermissionView.isHidden = !Current.motion.isActivityAvailable()

        notificationsPermissionView.delegate = self
        notificationsPermissionView.permission.updateInitial()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? ConnectInstanceViewController {
            vc.instance = instance
            vc.connectionInfo = connectionInfo
        }
    }

    func statusChanged(_ forPermission: PermissionType, _ toStatus: PermissionStatus) {
        Current.Log.verbose("Permission \(forPermission.title) status changed to \(toStatus.description)")
    }
}
