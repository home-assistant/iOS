@testable import HomeAssistant
import UIKit
import WebKit
import XCTest

/// A web view that is in no window has a hidden page, which is the only way to stop a frontend from
/// rendering in a Mac window nobody can see.
@MainActor
final class WebViewParkingTests: XCTestCase {
    private var scheduledActions: [@MainActor () -> Void] = []
    private var scheduledDelays: [TimeInterval] = []
    private var cancelledTimers = 0

    private var container: UIView!
    private var below: UIView!
    private var above: UIView!
    private var webView: WKWebView!

    override func setUp() {
        super.setUp()
        container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        below = UIView()
        above = UIView()
        webView = WKWebView(frame: CGRect(x: 0, y: 40, width: 320, height: 600))
        container.addSubview(below)
        container.addSubview(webView)
        container.addSubview(above)
    }

    override func tearDown() {
        scheduledActions = []
        scheduledDelays = []
        cancelledTimers = 0
        container = nil
        below = nil
        above = nil
        webView = nil
        super.tearDown()
    }

    func testParkingTakesTheWebViewOutAndUnparkingPutsItBackWhereItWas() {
        let sut = makeSUT()

        XCTAssertTrue(sut.park(webView))

        XCTAssertTrue(sut.isParked)
        XCTAssertEqual(container.subviews, [below, above])

        XCTAssertTrue(sut.unpark(webView, into: container))

        XCTAssertFalse(sut.isParked)
        XCTAssertEqual(container.subviews, [below, webView, above])
    }

    func testParkingAndUnparkingOutOfTurnChangeNothing() {
        let sut = makeSUT()

        XCTAssertFalse(sut.unpark(webView, into: container), "it is not parked")
        XCTAssertEqual(container.subviews, [below, webView, above])

        XCTAssertTrue(sut.park(webView))
        XCTAssertFalse(sut.park(webView), "it is parked already")

        XCTAssertFalse(makeSUT().park(webView), "a web view in no view cannot be parked")
    }

    /// Leaving the window costs the web view the keyboard, and typing has to go on working once the
    /// window is back.
    func testUnparkingGivesTheKeyboardBack() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.addSubview(container)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try XCTSkipUnless(webView.becomeFirstResponder(), "the web view cannot take the keyboard here")
        let sut = makeSUT()

        sut.park(webView)
        XCTAssertFalse(containsFirstResponder(webView))
        sut.unpark(webView, into: container)

        XCTAssertTrue(containsFirstResponder(webView))
    }

    func testOneActionAtATimeIsScheduledAndNoneWhileParked() throws {
        let sut = makeSUT()
        var runs = 0

        sut.schedule { runs += 1 }
        sut.schedule { runs += 1 }

        XCTAssertEqual(scheduledDelays, [30], "asking again while one is pending changes nothing")
        XCTAssertEqual(runs, 0)
        try XCTUnwrap(scheduledActions.first)()
        XCTAssertEqual(runs, 1)

        sut.schedule { runs += 1 }
        XCTAssertEqual(scheduledDelays, [30, 30], "one that has run makes room for the next")

        sut.cancelScheduled()
        sut.cancelScheduled()
        XCTAssertEqual(cancelledTimers, 1)

        sut.park(webView)
        sut.schedule { runs += 1 }
        XCTAssertEqual(scheduledDelays, [30, 30], "nothing is scheduled while the web view is parked")
    }

    /// A parking that is handed no timer keeps time with a real one.
    func testWithoutATimerOfItsOwnAnActionRunsAfterTheDelayAndACancelledOneNever() {
        let sut = WebViewParking(delay: 0.01)

        let ran = expectation(description: "the scheduled action ran")
        sut.schedule { ran.fulfill() }
        wait(for: [ran], timeout: 30)

        let cancelled = expectation(description: "a cancelled action ran")
        cancelled.isInverted = true
        sut.schedule { cancelled.fulfill() }
        sut.cancelScheduled()
        wait(for: [cancelled], timeout: 0.5)
    }

    private func makeSUT() -> WebViewParking {
        WebViewParking(
            delay: 30,
            scheduleTimer: { [unowned self] delay, action in
                scheduledDelays.append(delay)
                scheduledActions.append(action)
                return { [unowned self] in cancelledTimers += 1 }
            }
        )
    }

    private func containsFirstResponder(_ view: UIView) -> Bool {
        view.isFirstResponder || view.subviews.contains { containsFirstResponder($0) }
    }
}
