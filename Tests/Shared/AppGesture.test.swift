@testable import Shared
import UIKit
import XCTest

final class AppGestureTests: XCTestCase {
    private func recognizer(direction: UISwipeGestureRecognizer.Direction) -> UISwipeGestureRecognizer {
        let gesture = UISwipeGestureRecognizer()
        gesture.direction = direction
        return gesture
    }

    func testDefaultActionsForLeftSwipes() {
        let gestures: [AppGesture: HAGestureAction] = .defaultGestures

        XCTAssertEqual(gestures.getAction(for: recognizer(direction: .left), numberOfTouches: 1), .none)
        XCTAssertEqual(gestures.getAction(for: recognizer(direction: .left), numberOfTouches: 2), .nextPage)
        XCTAssertEqual(gestures.getAction(for: recognizer(direction: .left), numberOfTouches: 3), .previousServer)
    }

    func testDefaultActionsForRightSwipes() {
        let gestures: [AppGesture: HAGestureAction] = .defaultGestures

        XCTAssertEqual(gestures.getAction(for: recognizer(direction: .right), numberOfTouches: 1), .showSidebar)
        XCTAssertEqual(gestures.getAction(for: recognizer(direction: .right), numberOfTouches: 2), .backPage)
        XCTAssertEqual(gestures.getAction(for: recognizer(direction: .right), numberOfTouches: 3), .nextServer)
    }

    // Once a swipe reaches `.ended`, `numberOfTouches` reports 0. The handler must rely on
    // `numberOfTouchesRequired` so multi-finger swipes resolve to the configured action instead of `.none`.
    func testMultiFingerSwipeResolvesUsingNumberOfTouchesRequired() {
        let gestures: [AppGesture: HAGestureAction] = .defaultGestures

        let twoFingerLeft = recognizer(direction: .left)
        twoFingerLeft.numberOfTouchesRequired = 2
        XCTAssertEqual(
            gestures.getAction(for: twoFingerLeft, numberOfTouches: twoFingerLeft.numberOfTouchesRequired),
            .nextPage
        )

        let threeFingerLeft = recognizer(direction: .left)
        threeFingerLeft.numberOfTouchesRequired = 3
        XCTAssertEqual(
            gestures.getAction(for: threeFingerLeft, numberOfTouches: threeFingerLeft.numberOfTouchesRequired),
            .previousServer
        )

        // `numberOfTouches` is 0 on a freshly created recognizer, which would incorrectly yield `.none`.
        XCTAssertEqual(
            gestures.getAction(for: twoFingerLeft, numberOfTouches: twoFingerLeft.numberOfTouches),
            .none
        )
    }
}
