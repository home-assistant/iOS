@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

@MainActor
final class WebFrontendGesturesOverlayTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 390, height: 700)

    func testHitPolicyPassesThroughSingleFingerTapsAwayFromScreenEdges() {
        XCTAssertFalse(
            WebFrontendGesturesOverlay.HitPolicy.claimsHit(
                at: CGPoint(x: 195, y: 40),
                in: bounds,
                activeTouchCount: 1
            )
        )
        XCTAssertFalse(
            WebFrontendGesturesOverlay.HitPolicy.claimsHit(
                at: CGPoint(x: 195, y: 350),
                in: bounds,
                activeTouchCount: 0
            )
        )
    }

    func testHitPolicyClaimsMultiTouchSwipes() {
        XCTAssertTrue(
            WebFrontendGesturesOverlay.HitPolicy.claimsHit(
                at: CGPoint(x: 195, y: 350),
                in: bounds,
                activeTouchCount: 2
            )
        )
        XCTAssertTrue(
            WebFrontendGesturesOverlay.HitPolicy.claimsHit(
                at: CGPoint(x: 195, y: 350),
                in: bounds,
                activeTouchCount: 3
            )
        )
    }

    func testHitPolicyClaimsScreenEdgesForEdgePan() {
        XCTAssertTrue(
            WebFrontendGesturesOverlay.HitPolicy.claimsHit(
                at: CGPoint(x: 4, y: 350),
                in: bounds,
                activeTouchCount: 1
            )
        )
        XCTAssertTrue(
            WebFrontendGesturesOverlay.HitPolicy.claimsHit(
                at: CGPoint(x: bounds.maxX - 4, y: 350),
                in: bounds,
                activeTouchCount: 1
            )
        )
    }

    func testGesturesViewNeverClaimsHits() {
        let view = makeConfiguredView()

        XCTAssertNil(view.hitTest(CGPoint(x: 195, y: 40), with: nil))
        XCTAssertNil(view.hitTest(CGPoint(x: 195, y: 350), with: nil))
        XCTAssertNil(view.hitTest(CGPoint(x: 8, y: 350), with: nil))
        XCTAssertFalse(view.point(inside: CGPoint(x: 195, y: 40), with: nil))
        XCTAssertFalse(view.isUserInteractionEnabled)
    }

    func testWindowHostKeepsMultiTouchRecognizersTogether() throws {
        let window = UIWindow(frame: bounds)
        let view = makeConfiguredView()
        window.addSubview(view)
        view.frame = bounds
        window.layoutIfNeeded()

        let recognizers = try XCTUnwrap(window.gestureRecognizers)
        XCTAssertEqual(recognizers.filter { $0 is UISwipeGestureRecognizer }.count, 8)
        XCTAssertEqual(recognizers.filter { $0 is UIScreenEdgePanGestureRecognizer }.count, 2)
        XCTAssertTrue(recognizers.allSatisfy { !$0.cancelsTouchesInView })
    }

    func testStandByEmptyStateHeaderIsNotHitTestedAsTheGesturesOverlay() throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 2)
        let server = try XCTUnwrap(Current.servers.all.first)

        let host = UIHostingController(rootView: HomeAssistantStandByView(
            server: server,
            emptyState: WebFrontendOverlayState.EmptyStateContent(
                style: .disconnected,
                server: server,
                showsErrorDetailsButton: false,
                availableReauthURLTypes: [],
                retryAction: {},
                settingsAction: {},
                errorDetailsAction: {},
                reauthAction: { _ in },
                dismissAction: {}
            ),
            onGestureAction: { _ in }
        ))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        let overlay = host.view.ha_descendants().compactMap { $0 as? WebFrontendGesturesOverlay.GesturesView }
        XCTAssertEqual(overlay.count, 1, "The stand-by view should host exactly one gestures overlay")

        let headerPoint = CGPoint(x: 195, y: 56)
        let hit = host.view.hitTest(headerPoint, with: nil)
        XCTAssertFalse(
            hit is WebFrontendGesturesOverlay.GesturesView,
            "The disconnected-state server picker sits in the top header; the overlay must not own that hit"
        )
    }

    private func makeConfiguredView() -> WebFrontendGesturesOverlay.GesturesView {
        let overlay = WebFrontendGesturesOverlay { _ in }
        let view = WebFrontendGesturesOverlay.GesturesView(frame: bounds)
        view.coordinator = overlay.makeCoordinator()
        return view
    }
}

private extension UIView {
    func ha_descendants() -> [UIView] {
        subviews.flatMap { [$0] + $0.ha_descendants() }
    }
}
