import XCTest

/// Drives onboarding against a real Home Assistant, from the welcome screen to the native settings
/// screen the frontend opens over the external message bus.
///
/// Counterpart of `.maestro/onboarding.yaml` in home-assistant/android. Run by the `E2E` workflow,
/// never by `fastlane test`: it needs an instance seeded from `.github/e2e/homeassistant`, which
/// `Tools/home_assistant_e2e_auth.py` verifies before the app is ever launched.
final class OnboardingE2ETests: XCTestCase {
    private enum Timeout {
        /// Native screens, which either appear promptly or never will.
        static let screen: TimeInterval = 30
        /// Anything behind a round trip to Home Assistant, including the first paint of the frontend.
        static let frontend: TimeInterval = 120
        /// Prompts that are allowed not to appear at all.
        static let optional: TimeInterval = 10
    }

    /// Overridable through the runner's environment: `xcodebuild` forwards any `TEST_RUNNER_`
    /// variable into the test process with the prefix stripped.
    private enum Instance {
        static let url = value(for: "E2E_HOME_ASSISTANT_URL", default: "http://localhost:8123")
        static let username = value(for: "E2E_HOME_ASSISTANT_USERNAME", default: "citest")
        static let password = value(for: "E2E_HOME_ASSISTANT_PASSWORD", default: "h7jk99&U")

        private static func value(for key: String, default fallback: String) -> String {
            let value = ProcessInfo.processInfo.environment[key] ?? ""
            return value.isEmpty ? fallback : value
        }
    }

    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        // Onboards with the release client ID rather than the debug one. Home Assistant allows the
        // release iOS callback offline, but has to fetch `https://home-assistant.io/iOS/dev-auth`
        // to allow the debug one, and it reads only the first 10 KB of that page, which no longer
        // reaches the `redirect_uri` link tag. The debug pair is rejected with "Invalid redirect
        // URI", so the flow could never log in.
        app.launchArguments = ["-FASTLANE_SNAPSHOT", "YES"]
        app.launch()
    }

    func testOnboardingConnectsAndFrontendOpensNativeSettings() {
        connectToInstance()
        logIn()
        nameDevice()
        answerPermissions()
        dismissNotificationPermissionRequest()
        openNativeSettingsFromFrontend()
    }

    // MARK: - Steps

    private func connectToInstance() {
        tap(app.buttons[.onboardingWelcomeContinue], timeout: Timeout.screen, "welcome screen")
        tap(app.buttons[.onboardingServersManualEntry], timeout: Timeout.screen, "servers list")

        let urlField = app.textFields.firstMatch
        wait(for: urlField, timeout: Timeout.screen, "manual URL entry field")
        type(Instance.url, into: urlField, "manual URL entry field")

        tap(app.buttons[.onboardingManualEntryConnect], timeout: Timeout.screen, "connect button")
    }

    private func logIn() {
        let webView = app.webViews.firstMatch
        wait(for: webView, timeout: Timeout.frontend, "login web view")

        // Both fields are checked after typing: text aimed at a web view field lands wherever the
        // keyboard happens to be focused, and a miss otherwise surfaces only as a rejected login.
        let username = webView.textFields.firstMatch
        wait(for: username, timeout: Timeout.frontend, "username field")
        type(Instance.username, into: username, "username field")
        XCTAssertEqual(username.value as? String, Instance.username, "Username field did not receive the username")

        let password = webView.secureTextFields.firstMatch
        wait(for: password, timeout: Timeout.frontend, "password field")
        type(Instance.password, into: password, "password field")
        // Secure fields report one bullet per character rather than the text itself.
        XCTAssertEqual(
            (password.value as? String)?.count,
            Instance.password.count,
            "Password field did not receive the whole password"
        )

        // Submitting from the field avoids matching the login button, whose label the frontend
        // renders inside a shadow root.
        password.typeText("\n")

        // Shown only when Home Assistant asks to confirm the redirect back to the app.
        tapIfPresent(webElement(labelContaining: "authorize"), timeout: Timeout.optional)
    }

    private func nameDevice() {
        // Debug builds prefill the field, so the name only has to be accepted.
        tap(app.buttons[.onboardingDeviceNameSave], timeout: Timeout.frontend, "device name screen")
    }

    private func answerPermissions() {
        tap(
            app.buttons[.onboardingLocalOnlyDisclaimerContinue],
            timeout: Timeout.frontend,
            "local access disclaimer"
        )
        tap(app.buttons[.onboardingLocationSkip], timeout: Timeout.screen, "location permission screen")

        tap(
            app.buttons[.onboardingLocalAccessLessSecureOption],
            timeout: Timeout.screen,
            "less secure local access option"
        )
        tap(app.buttons[.onboardingLocalAccessNext], timeout: Timeout.screen, "local access next button")

        // Choosing the less secure level still asks iOS for location so the decision is recorded.
        // Denying it is what carries the flow past the home network step and into the frontend.
        denySystemAlert(timeout: Timeout.screen, "location permission alert")
    }

    private func dismissNotificationPermissionRequest() {
        let request = app.buttons[.notificationPermissionRequestSecondary]
        guard tapIfPresent(request, timeout: Timeout.frontend) else { return }
        denySystemAlert(timeout: Timeout.screen, "notification permission alert")
    }

    private func openNativeSettingsFromFrontend() {
        // Relaunched because asking the frontend for the settings screen in the same session that just
        // onboarded crashes the app: SwiftUI raises an unexpected error from
        // `NavigationColumnState.boundPathChange` the moment `AppSettingsPresenter.pushPath` gains its
        // first element. Onboarding runs its own `NavigationStack` inside the container's, and the
        // container's stack does not survive that nesting. Reproduces on iOS 26.5 and iOS 27; a
        // relaunched app pushes the same screen without complaint.
        app.terminate()
        app.launch()

        tapWebElement(labelContaining: "sidebar toggle", timeout: Timeout.frontend, "frontend sidebar toggle")
        tapWebElement(labelContaining: "settings", timeout: Timeout.frontend, "frontend sidebar settings entry")

        // The app's own settings screen is opened by the frontend over the external message bus, so
        // reaching it proves the bus is wired up in both directions.
        tapWebElement(labelContaining: "companion app", timeout: Timeout.frontend, "companion app row")
        wait(
            for: app.descendants(matching: .any)[.settingsList],
            timeout: Timeout.screen,
            "native settings screen"
        )
    }

    // MARK: - Helpers

    private func wait(for element: XCUIElement, timeout: TimeInterval, _ description: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Timed out waiting for the \(description)")
    }

    private func tap(_ element: XCUIElement, timeout: TimeInterval, _ description: String) {
        wait(for: element, timeout: timeout, description)
        element.tap()
    }

    /// Types into a field, waiting for it to actually take keyboard focus first.
    ///
    /// A tap on a web view field does not focus it synchronously: the page has to handle the touch
    /// and move focus itself. Typing before that fails outright with "Neither element nor any
    /// descendant has keyboard focus", so the tap is repeated until the keyboard is up.
    private func type(_ text: String, into element: XCUIElement, _ description: String) {
        // Always taps at least once, even when the keyboard is already up for a previous field,
        // since that tap is what moves focus to this one.
        var attempts = 0
        repeat {
            element.tap()
            attempts += 1
        } while !app.keyboards.element.waitForExistence(timeout: Timeout.optional) && attempts < 3

        XCTAssertTrue(app.keyboards.element.exists, "Keyboard never came up for the \(description)")
        element.typeText(text)
    }

    @discardableResult
    private func tapIfPresent(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    /// An element of the frontend, matched on part of its accessibility label.
    ///
    /// The frontend's own copy is the only handle here, so matching stays loose: a sidebar entry
    /// carries a badge when there are pending updates or repairs, and an exact label would miss it.
    private func webElement(labelContaining text: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let webView = app.webViews.firstMatch

        // Links and buttons first: a row's label usually also matches the static text inside it,
        // and tapping that does not activate the row.
        for query in [webView.links, webView.buttons] {
            let element = query.matching(predicate).firstMatch
            if element.exists {
                return element
            }
        }

        return webView.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Taps an element of the frontend, scrolling it into reach first when the page is long enough
    /// to render it below the fold.
    private func tapWebElement(labelContaining text: String, timeout: TimeInterval, _ description: String) {
        let element = webElement(labelContaining: text)
        wait(for: element, timeout: timeout, description)

        var scrolls = 0
        while !element.isHittable, scrolls < 3 {
            app.webViews.firstMatch.swipeUp()
            scrolls += 1
        }

        element.tap()
    }

    /// Answers a system permission alert with its denial button.
    ///
    /// The alert's buttons are whatever the permission offers ("Allow Once", "Allow While Using
    /// App", "Allow"), plus one that declines, which is the only one not offering access.
    private func denySystemAlert(timeout: TimeInterval, _ description: String) {
        let deny = NSPredicate(format: "NOT label BEGINSWITH[c] 'Allow'")

        let hosted = springboard.alerts.firstMatch.buttons.matching(deny).firstMatch
        if hosted.waitForExistence(timeout: timeout) {
            hosted.tap()
            return
        }

        // Not every iOS version presents these out of SpringBoard.
        tap(app.alerts.firstMatch.buttons.matching(deny).firstMatch, timeout: Timeout.optional, description)
    }
}

private extension XCUIElementQuery {
    subscript(identifier: AccessibilityIdentifier) -> XCUIElement {
        self[identifier.rawValue]
    }
}
