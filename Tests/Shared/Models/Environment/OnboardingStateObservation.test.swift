import Foundation
@testable import Shared
import XCTest

final class OnboardingStateObservationTests: XCTestCase {
    func testRegisteredObserversReceiveEveryState() {
        let observation = OnboardingStateObservation()
        let first = Observer()
        let second = Observer()
        observation.register(observer: first)
        observation.register(observer: second)

        observation.didConnect()
        observation.complete()
        observation.needed(.logout)
        observation.needed(.unauthenticated("server", 403))

        let expected: [OnboardingState] = [
            .didConnect,
            .complete,
            .needed(.logout),
            .needed(.unauthenticated("server", 403)),
        ]
        XCTAssertEqual(first.states, expected)
        XCTAssertEqual(second.states, expected)
    }

    func testUnregisteredObserverStopsReceivingStates() {
        let observation = OnboardingStateObservation()
        let observer = Observer()
        observation.register(observer: observer)
        observation.complete()

        observation.unregister(observer: observer)
        observation.needed(.error)

        XCTAssertEqual(observer.states, [.complete])
    }

    func testObserversAreHeldWeakly() {
        let observation = OnboardingStateObservation()
        weak var weakObserver: Observer?
        do {
            let observer = Observer()
            weakObserver = observer
            observation.register(observer: observer)
        }

        observation.complete()

        XCTAssertNil(weakObserver)
    }

    func testOnlyErrorsShowAnError() {
        XCTAssertTrue(OnboardingState.NeededType.error.shouldShowError)
        XCTAssertFalse(OnboardingState.NeededType.logout.shouldShowError)
        XCTAssertFalse(OnboardingState.NeededType.unauthenticated("server", 401).shouldShowError)
    }

    private final class Observer: OnboardingStateObserver {
        var states: [OnboardingState] = []

        func onboardingStateDidChange(to state: OnboardingState) {
            states.append(state)
        }
    }
}
