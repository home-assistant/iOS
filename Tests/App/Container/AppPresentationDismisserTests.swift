import Combine
@testable import HomeAssistant
import XCTest

@MainActor
final class AppPresentationDismisserTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testDismissAllClearsSettingsPresentationInEveryScene() {
        // A presenter per scene, as multi-window has: an incoming navigation clears all of them.
        let presenter = AppSettingsPresenter()
        let otherScenePresenter = AppSettingsPresenter()
        presenter.isSheetPresented = true
        presenter.isPushPresented = true
        otherScenePresenter.isSheetPresented = true

        AppPresentationDismisser.shared.dismissAll()

        XCTAssertFalse(presenter.isSheetPresented)
        XCTAssertFalse(presenter.isPushPresented)
        XCTAssertFalse(otherScenePresenter.isSheetPresented)
    }

    func testDismissAllNotifiesViewsOwningTheirOwnPresentationState() {
        var receivedCount = 0
        AppPresentationDismisser.shared.dismissAllPublisher
            .sink { receivedCount += 1 }
            .store(in: &cancellables)

        AppPresentationDismisser.shared.dismissAll()
        AppPresentationDismisser.shared.dismissAll()

        XCTAssertEqual(receivedCount, 2)
    }

    func testDismissAllDoesNotNotifyOnceAViewIsNoLongerObserving() {
        var receivedCount = 0
        let cancellable = AppPresentationDismisser.shared.dismissAllPublisher
            .sink { receivedCount += 1 }
        cancellable.cancel()

        AppPresentationDismisser.shared.dismissAll()

        XCTAssertEqual(receivedCount, 0)
    }
}
