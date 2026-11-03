import SwiftUI
import UIKit

/// Hosts a SwiftUI screen in an off-screen window (never the key window, which snapshot helpers
/// draw into) so its body is evaluated. SwiftUI controls expose no accessibility elements to
/// activate in a hosted unit test, so tests drive the view model and re-render with `layout()`.
@MainActor
final class CarPlaySwiftUIHost {
    let window: UIWindow
    let controller: UIViewController

    init(_ view: some View, height: CGFloat = 1600) {
        self.controller = UIHostingController(rootView: view)
        self.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: height))
        window.rootViewController = controller
        window.isHidden = false
        layout()
    }

    func layout() {
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }
}
