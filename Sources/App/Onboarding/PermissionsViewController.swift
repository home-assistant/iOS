import Shared
import UIKit

class PermissionsViewController: UIViewController, PermissionViewChangeDelegate {
    var instance: DiscoveredHomeAssistant!
    var connectionInfo: ConnectionInfo!

    @IBOutlet var continueButton: UIButton!
    @IBOutlet var locationPermissionView: PermissionLineItemView!
    @IBOutlet var motionPermissionView: PermissionLineItemView!
    @IBOutlet var notificationsPermissionView: PermissionLineItemView!
    @IBOutlet var focusPermissionView: PermissionLineItemView!

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

        focusPermissionView.delegate = self
        focusPermissionView.isHidden = !Current.focusStatus.isAvailable()
        focusPermissionView.permission.updateInitial()
    }

    @IBAction func continueTapped(_ sender: Any) {
        let controller = StoryboardScene.Onboarding.connectInstance.instantiate()
        controller.instance = instance
        controller.connectionInfo = connectionInfo
        show(controller, sender: self)
    }

    func statusChanged(_ forPermission: PermissionType, _ toStatus: PermissionStatus) {
        Current.Log.verbose("Permission \(forPermission.title) status changed to \(toStatus.description)")
    }
}
