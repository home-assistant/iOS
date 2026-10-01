import SwiftUI
import UIKit

/// Lays a view out in a window, which is what makes SwiftUI evaluate its body.
///
/// The window deliberately never becomes key: the snapshot helpers draw into whatever window is key, so
/// stealing it here would reach into unrelated tests. It is torn down again for the same reason.
@MainActor
public func renderInWindow(_ view: some View, height: CGFloat = 1400) {
    let controller = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: height))
    window.rootViewController = controller
    window.isHidden = false
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    window.isHidden = true
    window.rootViewController = nil
}
