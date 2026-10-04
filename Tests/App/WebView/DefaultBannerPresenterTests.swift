@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

/// The banner overlay `WebViewController` shows server alerts and other notices in: how requests are
/// compared, laid over the controller, replaced, dismissed and acted on.
@MainActor
final class DefaultBannerPresenterTests: XCTestCase {
    /// Records the requests a `WebViewController` hands to its presenter.
    private final class SpyBannerPresenter: BannerPresenter {
        private(set) var shownRequests: [BannerRequest] = []
        private(set) var hiddenIDs: [String] = []

        func show(on viewController: UIViewController, request: BannerRequest) {
            shownRequests.append(request)
        }

        func hide(id: String) {
            hiddenIDs.append(id)
        }
    }

    private var presenter: DefaultBannerPresenter!
    private var host: UIViewController!

    override func setUp() async throws {
        presenter = DefaultBannerPresenter()
        host = UIViewController()
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    }

    override func tearDown() async throws {
        presenter = nil
        host = nil
    }

    // MARK: - Helpers

    private func makeRequest(
        id: String = "banner",
        title: String? = "Title",
        message: String? = "Message",
        duration: BannerDuration = .forever,
        dimming: BannerDimming = .none,
        style: BannerStyle = .warning,
        action: BannerAction? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> BannerRequest {
        BannerRequest(
            id: id,
            title: title,
            message: message,
            duration: duration,
            dimming: dimming,
            style: style,
            action: action,
            onDismiss: onDismiss,
            dimmingAccessibilityLabel: "Dismiss"
        )
    }

    /// Lets the presenter's `DispatchQueue.main.async` work run.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    private func show(_ request: BannerRequest) {
        presenter.show(on: host, request: request)
        drainMainQueue()
    }

    /// The overlays currently laid over the host, each holding its banner as a subview.
    private var overlays: [UIView] {
        host.view.subviews.filter { overlay in
            overlay.subviews.contains { $0.accessibilityIdentifier != nil }
        }
    }

    private func banner(in overlay: UIView) -> UIView? {
        overlay.subviews.first { $0.accessibilityIdentifier != nil }
    }

    private func backgroundButton(in overlay: UIView) -> UIButton? {
        overlay.subviews.compactMap { $0 as? UIButton }.first
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }

    private func labels(in view: UIView) -> [UILabel] {
        descendants(of: view).compactMap { $0 as? UILabel }
    }

    private func actionButton(in overlay: UIView) -> UIButton? {
        guard let banner = banner(in: overlay) else { return nil }
        return descendants(of: banner).compactMap { $0 as? UIButton }.first
    }

    // MARK: - Value types

    func testBannerDurationEquality() {
        XCTAssertEqual(BannerDuration.forever, .forever)
        XCTAssertEqual(BannerDuration.seconds(3), .seconds(3))
        XCTAssertNotEqual(BannerDuration.seconds(3), .seconds(4))
        XCTAssertNotEqual(BannerDuration.seconds(3), .forever)
    }

    func testBannerDimmingInteractivityAndColor() {
        XCTAssertFalse(BannerDimming.none.isInteractive)
        XCTAssertFalse(BannerDimming.gray(interactive: false).isInteractive)
        XCTAssertTrue(BannerDimming.gray(interactive: true).isInteractive)

        XCTAssertEqual(BannerDimming.none.color, .clear)
        XCTAssertEqual(BannerDimming.gray(interactive: true).color, UIColor.black.withAlphaComponent(0.35))
    }

    func testBannerStyleEqualityComparesColors() {
        XCTAssertEqual(BannerStyle.warning, .warning)
        XCTAssertEqual(
            BannerStyle.card(backgroundColor: .red, foregroundColor: .white),
            BannerStyle(backgroundColor: .red, foregroundColor: .white)
        )
        XCTAssertNotEqual(BannerStyle.card(backgroundColor: .red, foregroundColor: .white), .warning)
    }

    func testRequestsMatchByIdOrByEverythingShown() {
        let base = makeRequest(id: "a")

        XCTAssertTrue(base.matchesPresentation(of: makeRequest(id: "a", title: "Other")))
        XCTAssertTrue(base.matchesPresentation(of: makeRequest(id: "b")))
        XCTAssertFalse(base.matchesPresentation(of: makeRequest(id: "b", title: "Other")))
        XCTAssertFalse(base.matchesPresentation(of: makeRequest(id: "b", message: "Other")))
        XCTAssertFalse(base.matchesPresentation(of: makeRequest(id: "b", duration: .seconds(1))))
        XCTAssertFalse(base.matchesPresentation(of: makeRequest(id: "b", dimming: .gray(interactive: true))))
        XCTAssertFalse(base.matchesPresentation(of: makeRequest(
            id: "b",
            style: .card(backgroundColor: .blue, foregroundColor: .white)
        )))
    }

    func testRequestsMatchOnlyWithAnEquivalentAction() {
        let action = BannerAction(title: "Open", tintColor: .white, handler: {})
        let withAction = makeRequest(id: "a", action: action)

        XCTAssertFalse(withAction.matchesPresentation(of: makeRequest(id: "b")))
        XCTAssertFalse(makeRequest(id: "a").matchesPresentation(of: makeRequest(id: "b", action: action)))
        XCTAssertTrue(withAction.matchesPresentation(of: makeRequest(
            id: "b",
            action: BannerAction(title: "Open", tintColor: .white, handler: {})
        )))
        XCTAssertFalse(withAction.matchesPresentation(of: makeRequest(
            id: "b",
            action: BannerAction(title: "Close", tintColor: .white, handler: {})
        )))
        XCTAssertFalse(withAction.matchesPresentation(of: makeRequest(
            id: "b",
            action: BannerAction(title: "Open", tintColor: .white, dismissOnTap: false, handler: {})
        )))
        XCTAssertFalse(withAction.matchesPresentation(of: makeRequest(
            id: "b",
            action: BannerAction(title: "Open", image: UIImage(), tintColor: .white, handler: {})
        )))
    }

    func testBannerActionDefaults() {
        let action = BannerAction(tintColor: .red, handler: {})

        XCTAssertNil(action.title)
        XCTAssertNil(action.image)
        XCTAssertNil(action.accessibilityLabel)
        XCTAssertTrue(action.dismissOnTap)
    }

    // MARK: - Presentation

    func testShowLaysTheBannerOverTheController() throws {
        show(makeRequest(id: "server-alert", title: "Heads up", message: "Something happened"))

        let overlay = try XCTUnwrap(overlays.first)
        XCTAssertEqual(overlays.count, 1)
        XCTAssertEqual(banner(in: overlay)?.accessibilityIdentifier, "server-alert")
        XCTAssertEqual(banner(in: overlay)?.backgroundColor, BannerStyle.warning.backgroundColor)

        let texts = try labels(in: XCTUnwrap(banner(in: overlay))).filter { !$0.isHidden }.compactMap(\.text)
        XCTAssertTrue(texts.contains("Heads up"))
        XCTAssertTrue(texts.contains("Something happened"))
        XCTAssertNil(actionButton(in: overlay))
    }

    func testMissingTitleAndMessageAreHidden() throws {
        show(makeRequest(title: nil, message: nil))

        let overlay = try XCTUnwrap(overlays.first)
        let bannerLabels = try labels(in: XCTUnwrap(banner(in: overlay)))
        XCTAssertEqual(bannerLabels.count, 2)
        XCTAssertTrue(bannerLabels.allSatisfy(\.isHidden))
    }

    func testShowingTheSameBannerAgainKeepsTheOneOnScreen() throws {
        show(makeRequest(id: "a"))
        let first = try XCTUnwrap(overlays.first)

        show(makeRequest(id: "a"))

        XCTAssertEqual(overlays.count, 1)
        XCTAssertTrue(overlays.first === first)
    }

    func testShowingADifferentBannerReplacesTheCurrentOne() throws {
        var dismissed = false
        show(makeRequest(id: "a", title: "First", onDismiss: { dismissed = true }))

        show(makeRequest(id: "b", title: "Second"))

        XCTAssertTrue(dismissed)
        XCTAssertEqual(overlays.count, 1)
        let overlay = try XCTUnwrap(overlays.first)
        XCTAssertEqual(banner(in: overlay)?.accessibilityIdentifier, "b")
    }

    func testHideWithAnotherIdKeepsTheBanner() {
        show(makeRequest(id: "a"))

        presenter.hide(id: "b")
        drainMainQueue()

        XCTAssertEqual(overlays.count, 1)
    }

    func testHideRemovesTheBannerAndReportsTheDismissal() {
        let dismissed = expectation(description: "banner dismissed")
        show(makeRequest(id: "a", onDismiss: { dismissed.fulfill() }))

        presenter.hide(id: "a")

        wait(for: [dismissed], timeout: 5)
        XCTAssertTrue(overlays.isEmpty)
    }

    func testTimedBannerDismissesItself() {
        let dismissed = expectation(description: "banner dismissed")
        show(makeRequest(id: "a", duration: .seconds(0.01), onDismiss: { dismissed.fulfill() }))

        wait(for: [dismissed], timeout: 5)
        XCTAssertTrue(overlays.isEmpty)
    }

    func testTappingTheActionRunsItAndDismisses() throws {
        let handled = expectation(description: "action handled")
        let dismissed = expectation(description: "banner dismissed")
        show(makeRequest(
            action: BannerAction(
                title: "Open",
                tintColor: .white,
                accessibilityLabel: "Open alert",
                handler: { handled.fulfill() }
            ),
            onDismiss: { dismissed.fulfill() }
        ))
        let overlay = try XCTUnwrap(overlays.first)
        let button = try XCTUnwrap(actionButton(in: overlay))
        XCTAssertEqual(button.title(for: .normal), "Open")
        XCTAssertEqual(button.accessibilityLabel, "Open alert")
        XCTAssertFalse(button.isHidden)

        button.sendActions(for: .touchUpInside)

        wait(for: [dismissed, handled], timeout: 5, enforceOrder: true)
        XCTAssertTrue(overlays.isEmpty)
    }

    func testTappingAnActionThatKeepsTheBannerLeavesItOnScreen() throws {
        var handledCount = 0
        show(makeRequest(action: BannerAction(
            image: UIImage(systemName: "xmark"),
            tintColor: .white,
            dismissOnTap: false,
            handler: { handledCount += 1 }
        )))
        let overlay = try XCTUnwrap(overlays.first)
        let button = try XCTUnwrap(actionButton(in: overlay))
        XCTAssertNil(button.title(for: .normal))
        XCTAssertNotNil(button.image(for: .normal))

        button.sendActions(for: .touchUpInside)
        drainMainQueue()

        XCTAssertEqual(handledCount, 1)
        XCTAssertEqual(overlays.count, 1)
    }

    func testTappingInteractiveDimmingDismisses() throws {
        let dismissed = expectation(description: "banner dismissed")
        show(makeRequest(dimming: .gray(interactive: true), onDismiss: { dismissed.fulfill() }))
        let overlay = try XCTUnwrap(overlays.first)
        let background = try XCTUnwrap(backgroundButton(in: overlay))
        XCTAssertTrue(background.isAccessibilityElement)
        XCTAssertEqual(background.accessibilityLabel, "Dismiss")

        background.sendActions(for: .touchUpInside)

        wait(for: [dismissed], timeout: 5)
        XCTAssertTrue(overlays.isEmpty)
    }

    func testTappingNonInteractiveDimmingDoesNothing() throws {
        var dismissed = false
        show(makeRequest(dimming: .gray(interactive: false), onDismiss: { dismissed = true }))
        let overlay = try XCTUnwrap(overlays.first)
        let background = try XCTUnwrap(backgroundButton(in: overlay))
        XCTAssertFalse(background.isAccessibilityElement)

        background.sendActions(for: .touchUpInside)
        drainMainQueue()

        XCTAssertFalse(dismissed)
        XCTAssertEqual(overlays.count, 1)
    }

    func testOnlyInteractiveDimmingCatchesTouchesOutsideTheBanner() throws {
        show(makeRequest(id: "passive", dimming: .none))
        let passive = try XCTUnwrap(overlays.first)
        host.view.layoutIfNeeded()
        XCTAssertFalse(passive.point(inside: CGPoint(x: 1, y: 1), with: nil))

        show(makeRequest(id: "modal", title: "Modal", dimming: .gray(interactive: true)))
        let modal = try XCTUnwrap(overlays.first { banner(in: $0)?.accessibilityIdentifier == "modal" })
        host.view.layoutIfNeeded()
        XCTAssertTrue(modal.point(inside: CGPoint(x: 1, y: 1), with: nil))
    }

    // MARK: - WebViewController

    func testServerAlertIsShownAsAPersistentWarningBanner() throws {
        let controller = WebViewController(server: Server.fake())
        let spy = SpyBannerPresenter()
        controller.bannerPresenter = spy
        let alertURL = try XCTUnwrap(URL(string: "https://alerts.home-assistant.io/alert"))
        let alert = ServerAlert(
            id: "alert-id",
            date: Date(timeIntervalSince1970: 0),
            url: alertURL,
            message: "Update your server",
            adminOnly: false,
            ios: .init(min: nil, max: nil),
            core: .init(min: nil, max: nil)
        )

        controller.show(alert: alert)
        controller.hideBanner(id: "alert-id")

        let request = try XCTUnwrap(spy.shownRequests.first)
        XCTAssertEqual(request.id, "alert-id")
        XCTAssertNil(request.title)
        XCTAssertEqual(request.message, "Update your server")
        XCTAssertEqual(request.duration, .forever)
        XCTAssertEqual(request.dimming, .gray(interactive: true))
        XCTAssertEqual(request.style, .warning)
        XCTAssertEqual(request.action?.title, L10n.openLabel)
        XCTAssertEqual(request.dimmingAccessibilityLabel, L10n.cancelLabel)
        XCTAssertNotNil(request.onDismiss)
        XCTAssertEqual(spy.hiddenIDs, ["alert-id"])
    }
}
