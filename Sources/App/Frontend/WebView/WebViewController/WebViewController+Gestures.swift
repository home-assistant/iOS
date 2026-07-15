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
        let action = Current.settingsStore.gestures.getAction(for: gesture, numberOfTouches: gesture.numberOfTouches)
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
