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

        title = L10n.SettingsDetails.General.Security.title

        form
            +++ Section()
            <<< SwitchRow("switch", {
                $0.title = L10n.SettingsDetails.General.Security.action
                $0.value = Current.settingsStore.biometricsRequired
                $0.onChange { row in
                    Current.settingsStore.biometricsRequired = row.value ?? false
                }
            })
            +++ Section(
                footer: L10n.SettingsDetails.General.Security.footer
            )
    }
}
