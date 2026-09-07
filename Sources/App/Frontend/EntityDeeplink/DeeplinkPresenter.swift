import Foundation
import Shared
import UIKit

enum DeeplinkPresenter {
    private static let detentIdentifier = UISheetPresentationController.Detent.Identifier("deeplink")

    static func present(target: DeeplinkTarget, from webViewController: WebViewControllerProtocol) {
        Current.Log.info("Opening deeplink for \(target)")

        let hostingController = DeeplinkView(
            viewModel: DeeplinkViewModel(
                target: target,
                serverName: webViewController.server.info.name
            ),
            onClose: { [weak webViewController] in
                webViewController?.dismissOverlayController(animated: true, completion: nil)
            }
        ).embeddedInHostingController()

        if Current.isCatalyst {
            hostingController.modalPresentationStyle = .formSheet
        } else if let sheet = hostingController.sheetPresentationController {
            let detent = UISheetPresentationController.Detent.custom(identifier: detentIdentifier) { context in
                context.maximumDetentValue * 0.7
            }
            sheet.detents = [detent, .large()]
            sheet.selectedDetentIdentifier = detent.identifier
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }

        webViewController.presentOverlayController(controller: hostingController, animated: true)
    }
}
