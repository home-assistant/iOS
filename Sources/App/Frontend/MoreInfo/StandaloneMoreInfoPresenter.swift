import Foundation
import Shared
import UIKit

/// Shows an entity's details in a sheet of their own, in place of the frontend's more-info dialog.
///
/// The frontend sends `more_info/open` instead of opening its dialog once the app reports
/// `hasNativeMoreInfo`. The sheet hosts a second web view on the frontend's frameless `/more-info`
/// route; its close button sends `more_info/close`, which the sheet's own controller answers by
/// dismissing itself (see `WebViewController.closeStandaloneMoreInfo()`).
@MainActor
final class StandaloneMoreInfoPresenter {
    nonisolated init() {}

    func present(entityId: String, from host: WebViewControllerProtocol) {
        Current.Log.info("Presenting standalone more-info for \(entityId)")

        let sheet = WebViewController(server: host.server, role: .standaloneMoreInfo(entityId: entityId))
        // Building the web view now lets it start before the presentation animation does.
        sheet.loadViewIfNeeded()
        Self.configurePresentation(of: sheet)

        // Siri resolves "this" against the entity on screen. The sheet publishes no activity of its
        // own, so the frontend underneath carries the entity while the sheet is up and drops it after.
        host.setOnscreenEntity(entityId: entityId)
        sheet.onDismiss = { [weak host] in
            host?.clearOnscreenEntity(entityId: entityId)
        }

        host.presentOverlayController(controller: sheet, animated: true)
    }

    static func configurePresentation(of controller: UIViewController) {
        if Current.isCatalyst {
            controller.modalPresentationStyle = .formSheet
        } else if let sheet = controller.sheetPresentationController {
            // The page fills the sheet, and with nothing to drag to there is no grabber.
            sheet.detents = [.large()]
        }
    }
}
