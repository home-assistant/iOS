import Shared
import SwiftUI
import UIKit

/// Recreates the `WebViewController` multi-touch swipe and screen-edge gestures for SwiftUI overlays that
/// cover the webview (like the stand-by view), so the user's configured gesture actions keep working there.
struct WebFrontendGesturesOverlay: UIViewRepresentable {
    let onGestureAction: (HAGestureAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        for numberOfTouches in [2, 3] {
            for direction: UISwipeGestureRecognizer.Direction in [.left, .right, .up, .down] {
                let gesture = UISwipeGestureRecognizer(
                    target: context.coordinator,
                    action: #selector(Coordinator.handleSwipe(_:))
                )
                gesture.numberOfTouchesRequired = numberOfTouches
                gesture.direction = direction
                gesture.delegate = context.coordinator
                view.addGestureRecognizer(gesture)
            }
        }

        for edge: UIRectEdge in [.left, .right] {
            let gesture = UIScreenEdgePanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleScreenEdgePan(_:))
            )
            gesture.edges = edge
            gesture.delegate = context.coordinator
            view.addGestureRecognizer(gesture)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
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
