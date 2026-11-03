import Foundation
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Gesture ordering, directions and the lookup from a recognized swipe to the configured action.
/// The lookup reads the gestures stored in the shared defaults, so the suite serializes.
@Suite(.sharedState)
struct AppGestureMappingTests {
    @Test func everyGestureHasAnOrderAndSwipesHaveADirection() {
        let orders = AppGesture.allCases.map(\.setupScreenOrder)
        #expect(Set(orders).count == AppGesture.allCases.count)
        for gesture in AppGesture.allCases {
            if gesture == .shake {
                #expect(gesture.direction == nil)
            } else {
                #expect(gesture.direction != nil, "\(gesture)")
            }
        }
    }

    @Test func swipesResolveToTheConfiguredActions() {
        let store = Current.settingsStore
        let previous = store.prefs.object(forKey: "gesturesSettings")
        defer { store.prefs.set(previous, forKey: "gesturesSettings") }

        var gestures = [AppGesture: HAGestureAction].defaultGestures
        gestures[.swipeLeft] = .nextServer
        store.gestures = gestures

        func action(_ direction: UISwipeGestureRecognizer.Direction, touches: Int) -> HAGestureAction {
            let recognizer = UISwipeGestureRecognizer()
            recognizer.direction = direction
            return gestures.getAction(for: recognizer, numberOfTouches: touches)
        }

        #expect(action(.left, touches: 1) == .nextServer)
        #expect(action(.left, touches: 2) == .nextPage)
        #expect(action(.left, touches: 3) == .previousServer)
        #expect(action(.left, touches: 4) == .none)
        #expect(action(.right, touches: 1) == .showSidebar)
        #expect(action(.right, touches: 2) == .backPage)
        #expect(action(.right, touches: 3) == .nextServer)
        #expect(action(.right, touches: 5) == .none)
        #expect(action(.up, touches: 3) == .showServersList)
        #expect(action(.up, touches: 1) == .none)
        #expect(action(.up, touches: 2) == .none)
        #expect(action(.down, touches: 1) == .none)
        #expect(action(.down, touches: 2) == .none)
        #expect(action([.left, .right], touches: 1) == .none)
    }
}
