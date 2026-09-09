import Shared
import SwiftUI
import UIKit

/// Opens Customize Tabs on a long press anywhere on the tab bar, which SwiftUI's `Tab` offers no hook for.
struct NativeTabBarLongPressInstaller: UIViewRepresentable {
    let onLongPress: () -> Void

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.onLongPress = onLongPress
        return view
    }

    func updateUIView(_ view: InstallerView, context: Context) {
        view.onLongPress = onLongPress
    }

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        static let minimumPressDuration: TimeInterval = 0.5

        var onLongPress: (() -> Void)?
        private(set) weak var recognizer: UILongPressGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installIfNeeded()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            installIfNeeded()
        }

        func installIfNeeded(in window: UIWindow? = nil) {
            guard recognizer == nil, let window = window ?? self.window,
                  let tabBar = NativeTabBarButtonLocator.tabBar(in: window) else { return }
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleRecognizer(_:)))
            recognizer.minimumPressDuration = Self.minimumPressDuration
            recognizer.delegate = self
            tabBar.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
        }

        func handle(state: UIGestureRecognizer.State) {
            guard state == .began else { return }
            Current.impactFeedback.impactOccurred(style: .light)
            onLongPress?()
        }

        @objc func handleRecognizer(_ recognizer: UILongPressGestureRecognizer) {
            handle(state: recognizer.state)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
