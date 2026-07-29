import Combine
@testable import HomeAssistant
import XCTest

@MainActor
final class AppPresentationDismisserTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        AppSettingsPresenter.shared.isSheetPresented = false
        AppSettingsPresenter.shared.isPushPresented = false
        super.tearDown()
    }

    func testDismissAllClearsSettingsPresentation() {
        AppSettingsPresenter.shared.isSheetPresented = true
        AppSettingsPresenter.shared.isPushPresented = true

        AppPresentationDismisser.shared.dismissAll()

        XCTAssertFalse(AppSettingsPresenter.shared.isSheetPresented)
        XCTAssertFalse(AppSettingsPresenter.shared.isPushPresented)
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
