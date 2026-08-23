@testable import HomeAssistant
import UIKit
import XCTest

@MainActor
final class HomeAssistantPullToRefreshObserverTests: XCTestCase {
    func testShortDocumentDoesNotForceVerticalBounce() {
        let (scrollView, _, _) = makeSUT(contentHeight: 400)

        XCTAssertTrue(scrollView.bounces)
        XCTAssertFalse(scrollView.alwaysBounceVertical)
    }

    func testScrollableDocumentEnablesVerticalBounce() {
        let (scrollView, _, _) = makeSUT(contentHeight: 1200)

        XCTAssertTrue(scrollView.alwaysBounceVertical)
    }

    func testPullFromTopSafeAreaOnShortDashboardTriggersRefresh() {
        let (scrollView, sut, state) = makeSUT(contentHeight: 400)

        performEligiblePull(on: sut, scrollView: scrollView, location: CGPoint(x: 195, y: 20))

        XCTAssertTrue(scrollView.alwaysBounceVertical)
        XCTAssertEqual(state.progress, 1, accuracy: 0.001)
        XCTAssertFalse(state.isRefreshing)

        sut.handlePan(state: .ended, locationInView: CGPoint(x: 195, y: 20), translation: CGPoint(x: 0, y: 90))

        XCTAssertEqual(state.refreshCount, 1)
        XCTAssertTrue(state.isRefreshing)
        XCTAssertEqual(state.progress, 1, accuracy: 0.001)
        XCTAssertEqual(scrollView.contentOffset.y, 0, accuracy: 0.5)
    }

    func testMiddleOfScreenDragOnShortDocumentDoesNotTriggerRefresh() {
        let (scrollView, sut, state) = makeSUT(contentHeight: 400)

        sut.handlePan(state: .began, locationInView: CGPoint(x: 195, y: 220), translation: .zero)
        XCTAssertFalse(scrollView.alwaysBounceVertical)

        pull(scrollView, to: -80, dragging: true)
        sut.handleContentOffset(scrollView.contentOffset)
        sut.handlePan(state: .ended, locationInView: CGPoint(x: 195, y: 220), translation: CGPoint(x: 0, y: 90))

        XCTAssertEqual(state.refreshCount, 0)
        XCTAssertEqual(state.progress, 0)
        XCTAssertFalse(state.isRefreshing)
    }

    func testVerticalRubberBandFromTopOfScrollableDashboardTriggersRefresh() {
        let (scrollView, sut, state) = makeSUT(contentHeight: 1200)

        performEligiblePull(on: sut, scrollView: scrollView, location: CGPoint(x: 195, y: 220))
        sut.handlePan(state: .ended, locationInView: CGPoint(x: 195, y: 220), translation: CGPoint(x: 0, y: 90))

        XCTAssertEqual(state.refreshCount, 1)
        XCTAssertTrue(state.isRefreshing)
    }

    func testHorizontalCanvasDragDoesNotTriggerRefresh() {
        let (scrollView, sut, state) = makeSUT(contentHeight: 1200)

        performEligiblePull(on: sut, scrollView: scrollView, location: CGPoint(x: 195, y: 220))
        sut.handlePan(state: .changed, locationInView: CGPoint(x: 260, y: 220), translation: CGPoint(x: 40, y: 50))
        sut.handlePan(state: .ended, locationInView: CGPoint(x: 260, y: 280), translation: CGPoint(x: 40, y: 90))

        XCTAssertEqual(state.refreshCount, 0)
        XCTAssertEqual(state.progress, 0)
        XCTAssertFalse(state.isRefreshing)
    }

    func testPanThatDoesNotBeginAtTopDoesNotTriggerRefresh() {
        let (scrollView, sut, state) = makeSUT(contentHeight: 1200)
        scrollView.contentOffset = CGPoint(x: 0, y: 180)

        sut.handlePan(state: .began, locationInView: CGPoint(x: 195, y: 20), translation: .zero)
        pull(scrollView, to: -80, dragging: true)
        sut.handleContentOffset(scrollView.contentOffset)
        sut.handlePan(state: .ended, locationInView: CGPoint(x: 195, y: 20), translation: CGPoint(x: 0, y: 90))

        XCTAssertEqual(state.refreshCount, 0)
        XCTAssertFalse(state.isRefreshing)
    }

    func testFinishRefreshingResetsLeftoverOffsetAndProgress() {
        let (scrollView, sut, state) = makeSUT(contentHeight: 400)

        performEligiblePull(on: sut, scrollView: scrollView, location: CGPoint(x: 195, y: 20))
        sut.handlePan(state: .ended, locationInView: CGPoint(x: 195, y: 20), translation: CGPoint(x: 0, y: 90))
        XCTAssertEqual(state.refreshCount, 1)

        pull(scrollView, to: -36, dragging: false)
        sut.finishRefreshing()

        XCTAssertEqual(state.progress, 0)
        XCTAssertFalse(state.isRefreshing)
        XCTAssertEqual(scrollView.contentOffset.y, 0, accuracy: 0.5)
        XCTAssertFalse(scrollView.alwaysBounceVertical)
    }

    func testLeftoverOffsetWhileNotDraggingDoesNotKeepProgress() {
        let (scrollView, sut, state) = makeSUT(contentHeight: 400)

        performEligiblePull(on: sut, scrollView: scrollView, location: CGPoint(x: 195, y: 20))
        XCTAssertEqual(state.progress, 1, accuracy: 0.001)

        pull(scrollView, to: -40, dragging: false)
        sut.handleContentOffset(scrollView.contentOffset)

        XCTAssertEqual(state.progress, 0)
        XCTAssertFalse(state.isRefreshing)
        XCTAssertEqual(scrollView.contentOffset.y, 0, accuracy: 0.5)
    }

    func testFinishRefreshingDoesNotYankScrolledContent() {
        let (scrollView, sut, _) = makeSUT(contentHeight: 1200)
        scrollView.contentOffset = CGPoint(x: 0, y: 240)

        sut.finishRefreshing()

        XCTAssertEqual(scrollView.contentOffset.y, 240, accuracy: 0.5)
    }

    private func performEligiblePull(
        on sut: HomeAssistantPullToRefreshObserver,
        scrollView: FakePullToRefreshScrollView,
        location: CGPoint
    ) {
        sut.handlePan(state: .began, locationInView: location, translation: .zero)
        pull(scrollView, to: -80, dragging: true)
        sut.handleContentOffset(scrollView.contentOffset)
    }

    private func pull(_ scrollView: FakePullToRefreshScrollView, to offsetY: CGFloat, dragging: Bool) {
        scrollView.stubIsDragging = dragging
        scrollView.stubIsTracking = dragging
        scrollView.stubIsDecelerating = false
        scrollView.contentOffset = CGPoint(x: 0, y: offsetY)
    }

    private func makeSUT(
        contentHeight: CGFloat,
        boundsHeight: CGFloat = 400
    ) -> (FakePullToRefreshScrollView, HomeAssistantPullToRefreshObserver, PullState) {
        let scrollView = FakePullToRefreshScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: boundsHeight))
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentSize = CGSize(width: 390, height: contentHeight)
        scrollView.stubSafeAreaInsets = UIEdgeInsets(top: 47, left: 0, bottom: 34, right: 0)

        let state = PullState()
        let sut = HomeAssistantPullToRefreshObserver(
            scrollView: scrollView,
            maximumThreshold: 148,
            onStateChange: { progress, isRefreshing in
                state.progress = progress
                state.isRefreshing = isRefreshing
            },
            onRefresh: {
                state.refreshCount += 1
            }
        )
        return (scrollView, sut, state)
    }
}

private final class PullState {
    var progress: CGFloat = 0
    var isRefreshing = false
    var refreshCount = 0
}

private final class FakePullToRefreshScrollView: UIScrollView {
    var stubSafeAreaInsets: UIEdgeInsets = .zero
    var stubIsDragging = false
    var stubIsTracking = false
    var stubIsDecelerating = false

    override var safeAreaInsets: UIEdgeInsets { stubSafeAreaInsets }
    override var adjustedContentInset: UIEdgeInsets { contentInset }
    override var isDragging: Bool { stubIsDragging }
    override var isTracking: Bool { stubIsTracking }
    override var isDecelerating: Bool { stubIsDecelerating }
}
