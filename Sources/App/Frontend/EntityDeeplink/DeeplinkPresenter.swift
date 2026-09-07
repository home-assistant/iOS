import Foundation
import Shared
import UIKit

enum DeeplinkPresenter {
    static let sheetHeightFraction: CGFloat = 0.7
    private static let detentIdentifier = UISheetPresentationController.Detent.Identifier("deeplink")

    static func present(target: DeeplinkTarget, from webViewController: WebViewControllerProtocol) {
        Current.Log.info("Presenting deeplink sheet")

        let hostingController = DeeplinkView(
            viewModel: DeeplinkViewModel(
                target: target,
                serverName: webViewController.server.info.name
            ),
            onClose: closeAction(for: webViewController)
        ).embeddedInHostingController()

        configurePresentation(of: hostingController)
        webViewController.presentOverlayController(controller: hostingController, animated: true)
    }

    static func closeAction(for webViewController: WebViewControllerProtocol) -> () -> Void {
        { [weak webViewController] in
            webViewController?.dismissOverlayController(animated: true, completion: nil)
        }
    }

    static func sheetHeight(maximum: CGFloat) -> CGFloat {
        maximum * sheetHeightFraction
    }

    private static func configurePresentation(of controller: UIViewController) {
        if Current.isCatalyst {
            controller.modalPresentationStyle = .formSheet
        } else if let sheet = controller.sheetPresentationController {
            let detent = UISheetPresentationController.Detent.custom(identifier: detentIdentifier) { context in
                sheetHeight(maximum: context.maximumDetentValue)
            }
            sheet.detents = [detent, .large()]
            sheet.selectedDetentIdentifier = detent.identifier
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
    }
}
