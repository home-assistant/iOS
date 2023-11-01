import Eureka
import FirebaseInstallations
import FirebaseMessaging
import PromiseKit
import RealmSwift
import Shared
import UIKit

class SecurityViewController: HAFormViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Security"

        form
            +++ Section()
            <<< SwitchRow("switch", {
                $0.title = NSLocalizedString("Enable biometric lock", comment: "")
                $0.value = Current.settingsStore.biometricsRequired
                $0.onChange { row in
                    Current.settingsStore.biometricsRequired = row.value ?? false
                }
            })
            +++ Section(
                footer: NSLocalizedString(
                    "You will be required to authenticate with biometrics everytime you open the app.",
                    comment: ""
                )
            )
    }
}
