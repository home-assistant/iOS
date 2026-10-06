import SwiftUI
import UIKit

/// Hosts the sheet's `WebViewController` in SwiftUI. The controller is long-lived and reused across
/// entities, so this only places it; it never rebuilds it.
struct NativeModalWebView: UIViewControllerRepresentable {
    let controller: WebViewController

    func makeUIViewController(context: Context) -> WebViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {}
}
