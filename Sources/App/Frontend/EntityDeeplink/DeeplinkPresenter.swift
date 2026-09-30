import Foundation
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum DeeplinkPresenter {
    static let sheetHeightFraction: CGFloat = 0.7
    #if os(iOS)
    private static let detentIdentifier = UISheetPresentationController.Detent.Identifier("deeplink")
    #endif

    static func present(target: DeeplinkTarget, from webViewController: WebViewControllerProtocol) {
        Current.Log.info("Presenting deeplink sheet")

        let hostingController = DeeplinkView(
            viewModel: DeeplinkViewModel(
                target: target,
                serverName: webViewController.server.info.name
            ),
            onClose: closeAction(for: webViewController)
        ).embeddedInHostingController()

        // A Mac sheet has no detents to pick from: the window presenting it decides its size.
        #if os(iOS)
        configurePresentation(of: hostingController)
        #endif
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

    #if os(iOS)
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
    #endif
}
