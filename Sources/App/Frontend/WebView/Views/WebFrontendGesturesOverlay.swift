import Shared
import SwiftUI
import UIKit

/// Recreates the `WebViewController` multi-touch swipe and screen-edge gestures for SwiftUI overlays that
/// cover the webview (like the stand-by view), so the user's configured gesture actions keep working there.
///
/// A full-screen `UIViewRepresentable` with `isUserInteractionEnabled` will otherwise eat taps meant for
/// SwiftUI/UIKit siblings (notably the empty-state server picker). Hits are claimed only for multi-touch
/// swipes and screen-edge pans; single-finger taps pass through.
struct WebFrontendGesturesOverlay: UIViewRepresentable {
    let onGestureAction: (HAGestureAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GesturesView {
        let view = GesturesView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: GesturesView, context: Context) {
        context.coordinator.parent = self
        uiView.coordinator = context.coordinator
    }

    /// Policy used by `GesturesView` (and tests) to decide whether a point should be claimed.
    enum HitPolicy {
        /// Width of the strip that still receives screen-edge pans.
        static let screenEdgeWidth: CGFloat = 20

        static func claimsHit(at point: CGPoint, in bounds: CGRect, activeTouchCount: Int) -> Bool {
            guard bounds.contains(point) else { return false }
            if activeTouchCount >= 2 { return true }
            return point.x <= screenEdgeWidth || point.x >= bounds.width - screenEdgeWidth
        }

        static func activeTouchCount(in event: UIEvent?) -> Int {
            event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? 0
        }
    }

    final class GesturesView: UIView {
        weak var coordinator: Coordinator? {
            didSet { reinstallWindowRecognizers() }
        }

        private var windowRecognizers: [UIGestureRecognizer] = []

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            // Never claim hits: the server picker and empty-state buttons sit in the same
            // SwiftUI hierarchy. Multi-touch/edge gestures are installed on the window so
            // both fingers stay on one recognizer host.
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reinstallWindowRecognizers()
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            false
        }

        private func reinstallWindowRecognizers() {
            windowRecognizers.forEach { $0.view?.removeGestureRecognizer($0) }
            windowRecognizers = []
            guard let window, let coordinator else { return }

            for numberOfTouches in [2, 3] {
                for direction: UISwipeGestureRecognizer.Direction in [.left, .right, .up, .down] {
                    let gesture = UISwipeGestureRecognizer(
                        target: coordinator,
                        action: #selector(Coordinator.handleSwipe(_:))
                    )
                    gesture.numberOfTouchesRequired = numberOfTouches
                    gesture.direction = direction
                    gesture.cancelsTouchesInView = false
                    gesture.delegate = coordinator
                    window.addGestureRecognizer(gesture)
                    windowRecognizers.append(gesture)
                }
            }

            for edge: UIRectEdge in [.left, .right] {
                let gesture = UIScreenEdgePanGestureRecognizer(
                    target: coordinator,
                    action: #selector(Coordinator.handleScreenEdgePan(_:))
                )
                gesture.edges = edge
                gesture.cancelsTouchesInView = false
                gesture.delegate = coordinator
                window.addGestureRecognizer(gesture)
                windowRecognizers.append(gesture)
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: WebFrontendGesturesOverlay

        init(parent: WebFrontendGesturesOverlay) {
            self.parent = parent
        }

        @objc
        func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
            guard gesture.state == .ended else { return }
            let action = Current.settingsStore.gestures.getAction(
                for: gesture,
                numberOfTouches: gesture.numberOfTouches
            )
            parent.onGestureAction(action)
        }

        @objc
        func handleScreenEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard gesture.state == .ended else { return }
            let appGesture: AppGesture = gesture.edges == .left ? .swipeRight : .swipeLeft
            parent.onGestureAction(Current.settingsStore.gestures[appGesture] ?? .none)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

#Preview {
    WebFrontendGesturesOverlay { _ in }
}
