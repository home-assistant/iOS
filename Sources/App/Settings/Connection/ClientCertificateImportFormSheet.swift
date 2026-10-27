import Shared
import SwiftUI
import UIKit

/// Presents the client certificate import as a UIKit form sheet while `request` is set, and dismisses
/// it once the request is answered. Used on Mac Catalyst, where SwiftUI sheet content doesn't receive
/// mouse events reliably; the web view presents the same import this way.
struct ClientCertificateImportFormSheet: UIViewControllerRepresentable {
    let request: OnboardingClientCertificateRequest?

    final class Coordinator {
        /// Only this sheet is dismissed: the presenting controller may be showing something else.
        weak var presented: UIViewController?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        let coordinator = context.coordinator
        if let request, coordinator.presented == nil {
            let sheet = UIHostingController(rootView: NavigationView {
                ClientCertificateOnboardingView(onImport: request.complete(with:), onCancel: request.cancel)
            }.navigationViewStyle(.stack))
            sheet.modalPresentationStyle = .formSheet
            sheet.isModalInPresentation = true
            controller.present(sheet, animated: true)
            coordinator.presented = sheet
        } else if request == nil, let presented = coordinator.presented {
            presented.dismiss(animated: true)
            coordinator.presented = nil
        }
    }
}

#Preview {
    ClientCertificateImportFormSheet(request: nil)
}
