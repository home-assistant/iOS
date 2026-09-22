import Foundation
@testable import HomeAssistant
import Improv_iOS
@testable import Shared
import Testing

/// The frontend hides its own back arrow the moment `hasNativeBackButton` is on, so the flag and
/// the show/hide messages that follow it have to agree about when we draw one.
@MainActor
@Suite(.serialized)
struct NativeBackButtonStateTests {
    private func withDevice(
        hasHinge: Bool,
        tabBarEnabled: Bool,
        _ body: () async throws -> Void
    ) async throws {
        let previousIsTestFlight = Current.isTestFlight
        let previousTabBar = Current.appLabs.isEnabled(featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        defer {
            NativeBackButtonState.shared.hingeAvailabilityChanged(to: false)
            Current.appLabs.setEnabled(previousTabBar, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
            Current.isTestFlight = previousIsTestFlight
        }

        NativeBackButtonState.shared.hingeAvailabilityChanged(to: hasHinge)
        Current.isTestFlight = true
        Current.appLabs.setEnabled(tabBarEnabled, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        for _ in 0 ..< 100 where AppLabsFeature.iosNativeTabBar.isEnabled != tabBarEnabled {
            try await Task.sleep(for: .milliseconds(20))
        }

        try await body()
    }

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
}
