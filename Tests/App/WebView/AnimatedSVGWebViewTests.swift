@testable import HomeAssistant
import UIKit
import XCTest

@MainActor
final class AnimatedSVGWebViewTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    }

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    func testWarmWebViewIsReusedWhileItIsUnparented() {
        let resourceName = "cache-identity-unparented"

        let first = AnimatedSVGWebViewCache.shared.webView(for: resourceName)
        let second = AnimatedSVGWebViewCache.shared.webView(for: resourceName)

        XCTAssertIdentical(first, second)
    }

    func testParentedWarmWebViewIsNotHandedOutASecondTime() {
        let resourceName = "cache-identity-parented"
        let first = AnimatedSVGWebViewCache.shared.webView(for: resourceName)
        window.addSubview(first)

        let second = AnimatedSVGWebViewCache.shared.webView(for: resourceName)

        XCTAssertNotIdentical(first, second)
        XCTAssertEqual(second.resourceName, resourceName)
    }

    func testAnimationRunsOnceTheViewIsOnScreen() async {
        let webView = AnimatedSVGWebView(resourceName: HomeAssistantStandByView.loadingLogoResourceName)

        window.addSubview(webView)

        let isAnimating = await waitUntilAnimating(webView)
        XCTAssertTrue(isAnimating, "The loading logo should animate as soon as it is on screen")
    }

    /// The reported bug: WebKit stops the page while the view sits off-screen — unparented between
    /// appearances, or unparented since the launch preload — and nothing used to restart it, so the
    /// logo came back frozen. Pausing the animations stands in for what WebKit does off-screen.
    func testReattachingResumesAnAnimationThatWasStoppedOffScreen() async throws {
        let webView = AnimatedSVGWebView(resourceName: HomeAssistantStandByView.loadingLogoResourceName)
        window.addSubview(webView)
        let startedAnimating = await waitUntilAnimating(webView)
        XCTAssertTrue(startedAnimating)

        _ = try await webView.evaluateJavaScript(Self.pauseAnimationsScript)
        let isAnimatingWhilePaused = try await webView.evaluateJavaScript(Self.isAnimatingScript) as? Bool
        XCTAssertEqual(isAnimatingWhilePaused, false, "Precondition: the animations should be stopped")

        webView.removeFromSuperview()
        window.addSubview(webView)

        let resumed = await waitUntilAnimating(webView)
        XCTAssertTrue(resumed, "Re-attaching the view should get the logo animating again")
    }

    /// Polls the document instead of waiting a fixed delay: both the initial load and the resume run
    /// asynchronously inside WebKit, so there is no notification to await.
    private func waitUntilAnimating(_ webView: AnimatedSVGWebView, attempts: Int = 100) async -> Bool {
        for _ in 0 ..< attempts {
            let result = try? await webView.evaluateJavaScript(Self.isAnimatingScript)
            if result as? Bool == true {
                return true
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    private static let isAnimatingScript = """
    (function() {
        var animations = document.getAnimations ? document.getAnimations() : [];
        return animations.length > 0 && animations.every(function(animation) {
            return animation.playState === 'running';
        });
    })()
    """

    private static let pauseAnimationsScript = """
    (function() {
        document.getAnimations().forEach(function(animation) { animation.pause(); });
        return true;
    })()
    """
}
