import Foundation
@testable import Shared
import UIKit
import XCTest

/// Gesture configuration: action metadata, the default mapping, and resolving a recognized swipe to
/// the action the user assigned it. XCTest rather than Swift Testing because the swipe lookups read
/// the persisted gesture settings, which these tests set and restore.
final class AppGestureTests: XCTestCase {
    private var previousGesturesData: Data?

    override func setUp() {
        super.setUp()
        previousGesturesData = Current.settingsStore.prefs.data(forKey: "gesturesSettings")
    }

    override func tearDown() {
        Current.settingsStore.prefs.set(previousGesturesData, forKey: "gesturesSettings")
        super.tearDown()
    }

    func testCategoriesGroupTheActions() {
        XCTAssertEqual(HAGestureAction.showSidebar.category, .homeAssistant)
        XCTAssertEqual(HAGestureAction.assist.category, .homeAssistant)
        XCTAssertEqual(HAGestureAction.searchCommands.category, .homeAssistant)
        XCTAssertEqual(HAGestureAction.backPage.category, .page)
        XCTAssertEqual(HAGestureAction.openInBrowser.category, .page)
        XCTAssertEqual(HAGestureAction.showServersList.category, .servers)
        XCTAssertEqual(HAGestureAction.previousServer.category, .servers)
        XCTAssertEqual(HAGestureAction.showSettings.category, .app)
        XCTAssertEqual(HAGestureAction.openDebug.category, .app)
        XCTAssertEqual(HAGestureAction.none.category, .other)

        for category in HAGestureActionCategory.allCases {
            XCTAssertFalse(category.localizedString.isEmpty, "\(category)")
        }
        XCTAssertEqual(
            Set(HAGestureActionCategory.allCases.map(\.localizedString)).count,
            HAGestureActionCategory.allCases.count
        )
    }

    func testEveryActionIsNamedAndHasItsOwnIcon() {
        for action in HAGestureAction.allCases {
            XCTAssertFalse(action.localizedString.isEmpty, "\(action)")
        }
        XCTAssertEqual(
            Set(HAGestureAction.allCases.map(\.localizedString)).count,
            HAGestureAction.allCases.count
        )
        XCTAssertEqual(
            Set(HAGestureAction.allCases.map { String(describing: $0.icon) }).count,
            HAGestureAction.allCases.count
        )
    }

    func testOnlySearchAndPageExportActionsExplainThemselves() {
        let explained: Set<HAGestureAction> = [
            .openInBrowser,
            .createDeeplink,
            .quickSearch,
            .searchEntities,
            .searchCommands,
            .searchDevices,
        ]
        for action in HAGestureAction.allCases {
            if explained.contains(action) {
                XCTAssertEqual(action.moreInfo?.isEmpty, false, "\(action)")
            } else {
                XCTAssertNil(action.moreInfo, "\(action)")
            }
        }
    }

    func testActionsRoundTripThroughCoding() throws {
        let data = try JSONEncoder().encode(HAGestureAction.allCases)
        XCTAssertEqual(try JSONDecoder().decode([HAGestureAction].self, from: data), HAGestureAction.allCases)
    }

    func testGestureTitlesOrderAndDirections() {
        XCTAssertEqual(AppGesture.swipeRight.localizedString, AppGesture.swipeLeft.localizedString)
        XCTAssertEqual(AppGesture._2FingersSwipeLeft.localizedString, AppGesture._2FingersSwipeRight.localizedString)
        XCTAssertEqual(AppGesture._3FingersSwipeUp.localizedString, AppGesture._3FingersSwipeLeft.localizedString)
        XCTAssertEqual(AppGesture._3FingersSwipeUp.localizedString, AppGesture._3FingersSwipeRight.localizedString)
        XCTAssertNotEqual(AppGesture.swipeRight.localizedString, AppGesture._2FingersSwipeRight.localizedString)
        XCTAssertFalse(AppGesture.shake.localizedString.isEmpty)

        XCTAssertEqual(
            AppGesture.allCases.sorted { $0.setupScreenOrder < $1.setupScreenOrder },
            [
                .swipeRight,
                .swipeLeft,
                ._2FingersSwipeRight,
                ._2FingersSwipeLeft,
                ._3FingersSwipeUp,
                ._3FingersSwipeRight,
                ._3FingersSwipeLeft,
                .shake,
            ]
        )

        XCTAssertEqual(AppGesture.swipeRight.direction, .right)
        XCTAssertEqual(AppGesture.swipeLeft.direction, .left)
        XCTAssertEqual(AppGesture._2FingersSwipeRight.direction, .right)
        XCTAssertEqual(AppGesture._2FingersSwipeLeft.direction, .left)
        XCTAssertEqual(AppGesture._3FingersSwipeUp.direction, .up)
        XCTAssertEqual(AppGesture._3FingersSwipeRight.direction, .right)
        XCTAssertEqual(AppGesture._3FingersSwipeLeft.direction, .left)
        XCTAssertNil(AppGesture.shake.direction)
    }

    func testDefaultGestures() {
        let defaults = [AppGesture: HAGestureAction].defaultGestures
        XCTAssertEqual(defaults[.swipeRight], .showSidebar)
        XCTAssertEqual(defaults[._2FingersSwipeRight], .backPage)
        XCTAssertEqual(defaults[._2FingersSwipeLeft], .nextPage)
        XCTAssertEqual(defaults[._3FingersSwipeUp], .showServersList)
        XCTAssertEqual(defaults[._3FingersSwipeRight], .nextServer)
        XCTAssertEqual(defaults[._3FingersSwipeLeft], .previousServer)
        XCTAssertEqual(defaults[.shake], HAGestureAction.none)
        XCTAssertNil(defaults[.swipeLeft])
    }

    @MainActor
    func testSwipesResolveToTheAssignedActions() {
        let assigned: [AppGesture: HAGestureAction] = [
            .swipeLeft: .quickSearch,
            .swipeRight: .showSidebar,
            ._2FingersSwipeLeft: .nextPage,
            ._2FingersSwipeRight: .backPage,
            ._3FingersSwipeUp: .showServersList,
            ._3FingersSwipeLeft: .previousServer,
            ._3FingersSwipeRight: .nextServer,
        ]
        Current.settingsStore.gestures = assigned

        func action(_ direction: UISwipeGestureRecognizer.Direction, touches: Int) -> HAGestureAction {
            let recognizer = UISwipeGestureRecognizer()
            recognizer.direction = direction
            return assigned.getAction(for: recognizer, numberOfTouches: touches)
        }

        XCTAssertEqual(action(.left, touches: 1), .quickSearch)
        XCTAssertEqual(action(.left, touches: 2), .nextPage)
        XCTAssertEqual(action(.left, touches: 3), .previousServer)
        XCTAssertEqual(action(.left, touches: 4), HAGestureAction.none)
        XCTAssertEqual(action(.right, touches: 1), .showSidebar)
        XCTAssertEqual(action(.right, touches: 2), .backPage)
        XCTAssertEqual(action(.right, touches: 3), .nextServer)
        XCTAssertEqual(action(.right, touches: 5), HAGestureAction.none)
        XCTAssertEqual(action(.up, touches: 3), .showServersList)
        XCTAssertEqual(action(.up, touches: 1), HAGestureAction.none)
        XCTAssertEqual(action(.up, touches: 2), HAGestureAction.none)
        XCTAssertEqual(action(.down, touches: 1), HAGestureAction.none)
        XCTAssertEqual(action(.down, touches: 3), HAGestureAction.none)
        XCTAssertEqual(action([.left, .up], touches: 1), HAGestureAction.none)
    }

    @MainActor
    func testUnassignedSwipesDoNothing() {
        Current.settingsStore.gestures = [:]

        let recognizer = UISwipeGestureRecognizer()
        recognizer.direction = .left
        XCTAssertEqual(
            [AppGesture: HAGestureAction]().getAction(for: recognizer, numberOfTouches: 1),
            HAGestureAction.none
        )
    }
}
