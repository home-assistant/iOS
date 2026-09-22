import Foundation
@testable import HomeAssistant
import Improv_iOS
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The frontend hides its own back arrow the moment `hasNativeBackButton` is on, so the flag, the
/// show/hide messages that follow it, and the toolbar we draw all have to agree.
///
/// One serialized suite covers all three: they share `NativeBackButtonState.shared` and the App
/// Labs flag, and separate suites would run against each other's setup.
@MainActor
@Suite(.serialized)
struct NativeBackButtonTests {
    private func withDevice(
        hasHinge: Bool,
        tabBarEnabled: Bool,
        _ body: () async throws -> Void
    ) async throws {
        let previousIsTestFlight = Current.isTestFlight
        let previousTabBar = Current.appLabs.isEnabled(featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        defer {
            NativeBackButtonState.shared.hide()
            NativeBackButtonState.shared.hingeAvailabilityChanged(to: false)
            Current.appLabs.setEnabled(previousTabBar, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
            Current.isTestFlight = previousIsTestFlight
        }

        Current.isTestFlight = true
        Current.appLabs.setEnabled(tabBarEnabled, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        for _ in 0 ..< 100 where AppLabsFeature.iosNativeTabBar.isEnabled != tabBarEnabled {
            try await Task.sleep(for: .milliseconds(20))
        }
        NativeBackButtonState.shared.hingeAvailabilityChanged(to: hasHinge)

        try await body()
    }

    /// Renders the toolbar the way a tab does and counts the controls it put on screen.
    ///
    /// The content itself draws none, so any control on screen is the toolbar's. Both the label
    /// and the bar are out of reach of a plain view walk: SwiftUI exposes a toolbar item's label
    /// through an accessibility element rather than the `UIView` it draws, and the bar it builds
    /// is not a `UINavigationBar`.
    @available(iOS 26, *)
    private func renderedControlCount(state: NativeBackButtonState) async throws -> Int {
        let controller = UIHostingController(
            rootView: Color.clear.modifier(
                NativeBackButtonToolbar(state: state, webViewController: nil)
            )
        )
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        // The bar is built a run loop turn after the navigation stack comes up.
        try await Task.sleep(for: .milliseconds(300))
        window.layoutIfNeeded()
        defer { window.isHidden = true }

        var controls = 0
        var queue: [UIView] = [window]
        while let view = queue.popLast() {
            if view is UIControl, !view.isHidden {
                controls += 1
            }
            queue.append(contentsOf: view.subviews)
        }

        return controls
    }

    // MARK: - Reporting the flag

    @Test("The frontend is only told to drop its back arrow on a hinged device with the tab bar on")
    func supportedOnlyOnAHingedDevice() async throws {
        try await withDevice(hasHinge: true, tabBarEnabled: true) {
            #expect(NativeBackButtonState.shared.isSupported)
            #expect(WebViewExternalBusMessage.configResult["hasNativeBackButton"] as? Bool == true)
        }

        // Every device without a hinge keeps the frontend's own back arrow.
        try await withDevice(hasHinge: false, tabBarEnabled: true) {
            #expect(!NativeBackButtonState.shared.isSupported)
            #expect(WebViewExternalBusMessage.configResult["hasNativeBackButton"] as? Bool == false)
        }

        // Without the tab bar there is no toolbar of ours to put the button in.
        try await withDevice(hasHinge: true, tabBarEnabled: false) {
            #expect(!NativeBackButtonState.shared.isSupported)
            #expect(WebViewExternalBusMessage.configResult["hasNativeBackButton"] as? Bool == false)
        }
    }

    @Test("A frontend already running on the old answer is reloaded, one that never asked is not")
    func staleReportIsDetected() async throws {
        try await withDevice(hasHinge: false, tabBarEnabled: true) {
            // Nothing has asked yet, so there is nothing to be stale about.
            #expect(!NativeBackButtonState.shared.isFrontendReportStale)

            #expect(WebViewExternalBusMessage.configResult["hasNativeBackButton"] as? Bool == false)
            #expect(!NativeBackButtonState.shared.isFrontendReportStale)

            // The hinge arrives only after the frontend already read the config.
            NativeBackButtonState.shared.hingeAvailabilityChanged(to: true)
            #expect(NativeBackButtonState.shared.isFrontendReportStale)

            // A reloaded frontend reads the new answer, and is no longer stale.
            #expect(WebViewExternalBusMessage.configResult["hasNativeBackButton"] as? Bool == true)
            #expect(!NativeBackButtonState.shared.isFrontendReportStale)
        }
    }

    @Test("Losing the hinge takes our back button away with it")
    func losingTheHingeHidesTheButton() async throws {
        try await withDevice(hasHinge: true, tabBarEnabled: true) {
            NativeBackButtonState.shared.show()
            #expect(NativeBackButtonState.shared.isVisible)

            NativeBackButtonState.shared.hingeAvailabilityChanged(to: false)
            #expect(!NativeBackButtonState.shared.isVisible)
        }
    }

    // MARK: - Talking to the frontend

    @Test("The bus messages of the frontend drive the button, and a page load clears it")
    func busMessagesDriveTheButton() {
        let handler = WebViewExternalMessageHandler(improvManager: ImprovManager.shared)
        let webViewController = MockWebViewController()
        handler.webViewController = webViewController
        NativeBackButtonState.shared.reset()

        handler.handleExternalMessage(["id": 1, "type": "back_button/show"])
        #expect(NativeBackButtonState.shared.isVisible)

        handler.handleExternalMessage(["id": 2, "type": "back_button/hide"])
        #expect(!NativeBackButtonState.shared.isVisible)

        handler.handleExternalMessage(["id": 3, "type": "back_button/show"])
        NativeBackButtonState.shared.reset()
        #expect(!NativeBackButtonState.shared.isVisible)
    }

    @Test("Tapping the button hands the navigation back to the frontend")
    func pressGoesBackToTheFrontend() async throws {
        let handler = WebViewExternalMessageHandler(improvManager: ImprovManager.shared)
        let webViewController = MockWebViewController()
        handler.webViewController = webViewController

        handler.sendBackButtonPressed()

        // The bus hops to the main queue before it evaluates anything.
        for _ in 0 ..< 100 where webViewController.lastEvaluatedJavaScriptScript == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        // JSONEncoder escapes the slash, so compare against the encoded form.
        let script = try #require(webViewController.lastEvaluatedJavaScriptScript)
        #expect(script.contains("\"command\":\"back_button\\/pressed\""))
        #expect(script.contains("\"type\":\"command\""))
    }

    // MARK: - Drawing the button

    @available(iOS 26, *)
    @Test("The button is there while the frontend reports a back action")
    func showsTheButtonWhenTheFrontendAsksForIt() async throws {
        let state = NativeBackButtonState(isTabBarEnabled: { true })
        state.hingeAvailabilityChanged(to: true)
        state.show()

        let controls = try await renderedControlCount(state: state)

        #expect(controls > 0)
    }

    @available(iOS 26, *)
    @Test("A page with nowhere to go back to gets no button")
    func hidesTheButtonWithoutABackAction() async throws {
        let state = NativeBackButtonState(isTabBarEnabled: { true })
        state.hingeAvailabilityChanged(to: true)
        state.hide()

        let controls = try await renderedControlCount(state: state)

        #expect(controls == 0)
    }

    @available(iOS 26, *)
    @Test("A device we never claimed the back button on keeps the frontend as it was")
    func addsNoChromeWhenUnsupported() async throws {
        let state = NativeBackButtonState(isTabBarEnabled: { true })
        state.show()

        let controls = try await renderedControlCount(state: state)

        #expect(controls == 0)
    }
}
