import SwiftUI
import Testing
import UIKit

/// Lays a view out in a window, which is what makes SwiftUI evaluate its body, and fails the test when the
/// body lays out to nothing. This is an iOS smoke test: it proves the screen still builds and takes up
/// space, not what it shows.
///
/// The window deliberately never becomes key: the snapshot helpers draw into whatever window is key, so
/// stealing it here would reach into unrelated tests. It is torn down again for the same reason.
@MainActor
public func renderInWindow(
    _ view: some View,
    height: CGFloat = 1400,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let controller = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: height))
    window.rootViewController = controller
    window.isHidden = false
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    let size = controller.sizeThatFits(in: window.bounds.size)
    #expect(size.width > 0 && size.height > 0, "The view laid out to nothing", sourceLocation: sourceLocation)

    window.isHidden = true
    window.rootViewController = nil
}
