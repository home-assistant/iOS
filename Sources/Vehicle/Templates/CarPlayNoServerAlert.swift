import CarPlay
import Foundation
import Shared

final class CarPlayNoServerAlert {
    weak var interfaceController: CPInterfaceController?

    func present() {
        let loginAlertAction = CPAlertAction(title: L10n.Carplay.Labels.alreadyAddedServer, style: .default) { _ in
            if !Current.servers.all.isEmpty {
                self.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }
        }
        let alertTemplate = CPAlertTemplate(
            titleVariants: [L10n.Carplay.Labels.noServersAvailable],
            actions: [loginAlertAction]
        )

        interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }
}
