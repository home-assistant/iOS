import Shared
import UIKit

// MARK: - Gesture Setup & Handling

extension WebViewController {
    func setupGestures(numberOfTouchesRequired: Int) {
        let gestures = [.left, .right, .up, .down].map { (direction: UISwipeGestureRecognizer.Direction) in
            let gesture = UISwipeGestureRecognizer()
            gesture.numberOfTouchesRequired = numberOfTouchesRequired
            gesture.direction = direction
            gesture.addTarget(self, action: #selector(swipe(_:)))
            gesture.delegate = self
            return gesture
        }

        for gesture in gestures {
            view.addGestureRecognizer(gesture)
        }
    }

    func setupEdgeGestures() {
        webView.addGestureRecognizer(leftEdgePanGestureRecognizer)
        webView.addGestureRecognizer(rightEdgeGestureRecognizer)
    }

    @objc func swipe(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        // Use `numberOfTouchesRequired` instead of `numberOfTouches`: once the swipe reaches the
        // `.ended` state the fingers have already lifted, so `numberOfTouches` reports 0 and the
        // multi-finger (2 and 3 fingers) gestures would resolve to `.none`.
        let action = Current.settingsStore.gestures.getAction(
            for: gesture,
            numberOfTouches: gesture.numberOfTouchesRequired
        )
        webViewGestureHandler.handleGestureAction(action)
    }

    @objc func screenEdgeGestureRecognizerAction(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        let gesture: AppGesture = gesture.edges == .left ? .swipeRight : .swipeLeft
        let action = Current.settingsStore.gestures[gesture] ?? .none
        webViewGestureHandler.handleGestureAction(action)
    }
}
