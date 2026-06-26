import Combine
import Shared
import UIKit

// MARK: - Gesture ownership at the SwiftUI layer

/// Owns the web frontend's swipe/edge gesture recognizers. It is created and held by `HomeAssistantView`
/// (the SwiftUI layer) and attached to the hosted `WebViewController`'s view, rather than being wired up
/// inside `WebViewController` itself.
///
/// Each recognizer is bound to a specific `AppGesture`, so the action it triggers is resolved from that fixed
/// identity. Previously the action was inferred from the recognizer's live `numberOfTouches` at recognition
/// time, which is unreliable for a discrete `UISwipeGestureRecognizer` (the touches have usually lifted by the
/// time `.ended` fires, so it reports `0`). That made every 2- and 3-finger swipe resolve to `.none` and
/// silently do nothing.
@MainActor
final class WebViewGestureManager: NSObject, ObservableObject {
    private weak var gestureHandler: WebViewGestureHandler?
    private weak var attachedView: UIView?

    /// Attaches the gesture recognizers to the controller's view. A no-op if already attached to that exact
    /// view; if a different view is provided (e.g. a server switch built a fresh controller), the recognizers
    /// move to the new view.
    func attach(to controller: WebViewController) {
        guard attachedView !== controller.view else { return }
        detach()

        let view = controller.view
        gestureHandler = controller.webViewGestureHandler
        attachedView = view

        // Multi-finger swipes (2- and 3-finger) anywhere over the frontend.
        for gesture in AppGesture.multiFingerSwipes {
            guard let direction = gesture.direction, let touches = gesture.numberOfTouchesRequired else { continue }
            let recognizer = AppSwipeGestureRecognizer(
                appGesture: gesture,
                target: self,
                action: #selector(handleSwipe(_:))
            )
            recognizer.direction = direction
            recognizer.numberOfTouchesRequired = touches
            recognizer.delegate = self
            view?.addGestureRecognizer(recognizer)
        }

        // Single-finger swipes are recognized as screen-edge pans: a swipe-right starts at the left edge and
        // a swipe-left starts at the right edge.
        view?.addGestureRecognizer(makeEdgeRecognizer(edges: .left, appGesture: .swipeRight))
        view?.addGestureRecognizer(makeEdgeRecognizer(edges: .right, appGesture: .swipeLeft))
    }

    /// Removes the recognizers this manager added from whatever view they are currently attached to.
    func detach() {
        guard let attachedView else { return }
        for recognizer in attachedView.gestureRecognizers ?? [] where recognizer is AppGestureRecognizing {
            attachedView.removeGestureRecognizer(recognizer)
        }
        self.attachedView = nil
    }

    private func makeEdgeRecognizer(edges: UIRectEdge, appGesture: AppGesture) -> AppScreenEdgePanGestureRecognizer {
        let recognizer = AppScreenEdgePanGestureRecognizer(
            appGesture: appGesture,
            target: self,
            action: #selector(handleEdgePan(_:))
        )
        recognizer.edges = edges
        recognizer.delegate = self
        return recognizer
    }

    @objc private func handleSwipe(_ recognizer: AppSwipeGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        perform(recognizer.appGesture)
    }

    @objc private func handleEdgePan(_ recognizer: AppScreenEdgePanGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        perform(recognizer.appGesture)
    }

    private func perform(_ gesture: AppGesture) {
        let action = Current.settingsStore.gestures[gesture] ?? .none
        gestureHandler?.handleGestureAction(action)
    }
}

extension WebViewGestureManager: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

// MARK: - AppGesture-bound recognizers

/// Marker that lets the manager identify (and later remove) only the recognizers it added.
protocol AppGestureRecognizing: AnyObject {
    var appGesture: AppGesture { get }
}

/// A swipe recognizer that remembers which `AppGesture` it represents, so the resolved action never depends on
/// the recognizer's live touch count.
final class AppSwipeGestureRecognizer: UISwipeGestureRecognizer, AppGestureRecognizing {
    let appGesture: AppGesture

    init(appGesture: AppGesture, target: Any?, action: Selector?) {
        self.appGesture = appGesture
        super.init(target: target, action: action)
    }
}

/// A screen-edge pan recognizer bound to a specific `AppGesture` (used for single-finger edge swipes).
final class AppScreenEdgePanGestureRecognizer: UIScreenEdgePanGestureRecognizer, AppGestureRecognizing {
    let appGesture: AppGesture

    init(appGesture: AppGesture, target: Any?, action: Selector?) {
        self.appGesture = appGesture
        super.init(target: target, action: action)
    }
}
