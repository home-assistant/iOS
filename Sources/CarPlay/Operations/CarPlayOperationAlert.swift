import CarPlay
import Foundation
import Shared

/// Tells the driver that an action didn't go through.
enum CarPlayOperationAlert {
    static func present(_ error: CarPlayOperationError, on interfaceController: CarPlayAlertPresenting?) {
        Current.Log.error("CarPlay action failed: \(error.logDescription)")

        guard let interfaceController else { return }

        // CarPlay shows one modal at a time. A burst of failures — a dead zone that catches several
        // rows at once, or a repeat tap — would otherwise stack alerts for the driver to dismiss one
        // by one, so anything arriving while a template is already up is logged and dropped.
        guard interfaceController.presentedTemplate == nil else { return }

        let alert = makeAlertTemplate(for: error) {
            interfaceController.dismissTemplate(animated: true, completion: nil)
        }
        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }

    static func makeAlertTemplate(
        for error: CarPlayOperationError,
        onDismiss: @escaping () -> Void
    ) -> CPAlertTemplate {
        CPAlertTemplate(
            titleVariants: error.alertTitleVariants,
            actions: [
                CPAlertAction(title: L10n.Alerts.Confirm.ok, style: .default) { _ in
                    onDismiss()
                },
            ]
        )
    }
}
