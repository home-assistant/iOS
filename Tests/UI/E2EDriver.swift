import XCTest

/// Drives one Home Assistant app through the steps the end-to-end tests share, matching elements by
/// accessibility identifier where the app owns them and by label where only the frontend does.
///
/// Several drivers can coexist in one test, one per installed app, which is how the transfer between the
/// previous and the new app is exercised on a single simulator.
final class E2EDriver {
    enum Timeout {
        /// Native screens, which either appear promptly or never will.
        static let screen: TimeInterval = 30
        /// Anything behind a round trip to Home Assistant, including the first paint of the frontend.
        static let frontend: TimeInterval = 120
        /// Prompts that are allowed not to appear at all.
        static let optional: TimeInterval = 10
    }

    /// Overridable through the runner's environment: `xcodebuild` forwards any `TEST_RUNNER_`
    /// variable into the test process with the prefix stripped.
    enum Instance {
        static let url = value(for: "E2E_HOME_ASSISTANT_URL", default: "http://localhost:8123")
        static let username = value(for: "E2E_HOME_ASSISTANT_USERNAME", default: "citest")
        static let password = value(for: "E2E_HOME_ASSISTANT_PASSWORD", default: "h7jk99&U")

        private static func value(for key: String, default fallback: String) -> String {
            let value = ProcessInfo.processInfo.environment[key] ?? ""
            return value.isEmpty ? fallback : value
        }
    }

    /// The two builds that take part in the transfer, both installed on the simulator.
    static let previousAppBundleID = "io.robbie.HomeAssistant.dev"
    static let newAppBundleID = "io.home-assistant.app.dev"

    let app: XCUIApplication
    private unowned let testCase: XCTestCase
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    init(app: XCUIApplication, testCase: XCTestCase) {
        self.app = app
        self.testCase = testCase
    }

    /// Launches with the release client ID rather than the debug one. Home Assistant allows the release
    /// iOS callback offline, but has to fetch `https://home-assistant.io/iOS/dev-auth` to allow the debug
    /// one, and it reads only the first 10 KB of that page, which no longer reaches the `redirect_uri`
    /// link tag. The debug pair is rejected with "Invalid redirect URI", so the flow could never log in.
    func launchForOnboarding() {
        app.launchArguments = ["-FASTLANE_SNAPSHOT", "YES"]
        app.launch()
    }

    /// From the welcome screen to the frontend with notifications granted.
    func onboard() {
        connectToInstance()
        logIn()
        nameDevice()
        answerPermissions()
        grantNotificationPermission()
    }

    // MARK: - Steps

    func connectToInstance() {
        tap(app.buttons[.onboardingWelcomeContinue], timeout: Timeout.screen, "welcome screen")
        tap(app.buttons[.onboardingServersManualEntry], timeout: Timeout.screen, "servers list")

        let urlField = app.textFields.firstMatch
        wait(for: urlField, timeout: Timeout.screen, "manual URL entry field")
        type(Instance.url, into: urlField, "manual URL entry field")

        tap(app.buttons[.onboardingManualEntryConnect], timeout: Timeout.screen, "connect button")
    }

    func logIn() {
        let webView = app.webViews.firstMatch
        wait(for: webView, timeout: Timeout.frontend, "login web view")

        // Text aimed at a web view field lands wherever the keyboard happens to be focused, and a
        // miss otherwise surfaces only as a rejected login, so both fields are typed with checks.
        let username = webView.textFields.firstMatch
        wait(for: username, timeout: Timeout.frontend, "username field")
        type(Instance.username, into: username, "username field")

        let password = webView.secureTextFields.firstMatch
        wait(for: password, timeout: Timeout.frontend, "password field")
        type(Instance.password, into: password, "password field", secure: true)

        // Submitting from the field avoids matching the login button, whose label the frontend
        // renders inside a shadow root.
        password.typeText("\n")

        // Shown only when Home Assistant asks to confirm the redirect back to the app.
        tapIfPresent(webElement(labelContaining: "authorize"), timeout: Timeout.optional)
    }

    func nameDevice() {
        // Debug builds prefill the field, so the name only has to be accepted.
        tap(app.buttons[.onboardingDeviceNameSave], timeout: Timeout.frontend, "device name screen")
    }

    func answerPermissions() {
        tap(
            app.buttons[.onboardingLocalOnlyDisclaimerContinue],
            timeout: Timeout.frontend,
            "local access disclaimer"
        )

        tap(app.buttons[.onboardingLocationShare], timeout: Timeout.screen, "location permission screen")
        allowSystemAlert(timeout: Timeout.screen, "location permission alert")

        // Granting "while using" makes the app ask for "always" on top of it, which iOS raises as a
        // second alert over the next screen. The flow has already moved on by then so either answer
        // will do, but it has to be cleared before anything below it can be tapped.
        answerSystemAlertIfPresent(timeout: Timeout.optional)

        // The secure level is what keeps the home network step in the flow: the less secure one
        // settles the decision on the spot and jumps straight to completion.
        tap(
            app.buttons[.onboardingLocalAccessSecureOption],
            timeout: Timeout.screen,
            "most secure local access option"
        )
        // No alert follows: location is already granted, so this step has nothing left to ask.
        tap(app.buttons[.onboardingLocalAccessNext], timeout: Timeout.screen, "local access next button")

        // Prefilled from the network the device reports, which is always "Simulator" here, so the
        // name only has to be accepted. Leaving it empty would stall the flow on a validation alert.
        tap(app.buttons[.onboardingHomeNetworkNext], timeout: Timeout.screen, "home network screen")
    }

    func grantNotificationPermission() {
        // The sheet is posted a few seconds after the frontend paints, so the wait for it starts
        // once that has happened rather than covering both and stalling if it never arrives.
        wait(for: app.webViews.firstMatch, timeout: Timeout.frontend, "frontend")

        let request = app.buttons[.notificationPermissionRequestPrimary]
        guard request.waitForExistence(timeout: Timeout.screen) else { return }

        dismiss(request, "notification permission sheet")
        // Both of the sheet's buttons ask iOS the same question, so the alert always follows.
        allowSystemAlert(timeout: Timeout.screen, "notification permission alert")
    }

    func openNativeSettingsFromFrontend() {
        // The toggle reports a successful tap even when the page swallows it, so the sidebar opening
        // is the only thing worth believing.
        tapWebElement(
            labelContaining: "sidebar toggle",
            until: webElement(labelContaining: "settings"),
            timeout: Timeout.frontend,
            "frontend sidebar"
        )
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

    func wait(for element: XCUIElement, timeout: TimeInterval, _ description: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Timed out waiting for the \(description)")
    }

    func tap(_ element: XCUIElement, timeout: TimeInterval, _ description: String) {
        wait(for: element, timeout: timeout, description)
        element.tap()
    }

    /// Types into a field, waiting for it to actually take keyboard focus first, and retypes when
    /// the field did not end up holding the text.
    ///
    /// A tap on a web view field does not focus it synchronously: the page has to handle the touch
    /// and move focus itself. Typing before that fails outright with "Neither element nor any
    /// descendant has keyboard focus", so the tap is repeated until the keyboard is up. On a freshly
    /// erased simulator iOS also covers the first keyboard with its typing tutorial, which swallows
    /// most keystrokes, so the tutorial is dismissed and the value checked after every attempt.
    func type(_ text: String, into element: XCUIElement, _ description: String, secure: Bool = false) {
        for _ in 1 ... 3 {
            focus(element, description)
            dismissKeyboardTutorialIfPresent()
            element.typeText(text)
            if holds(element, text, secure: secure) {
                return
            }
            clear(element)
        }
        XCTFail("The \(description) did not receive the text after three attempts")
    }

    private func focus(_ element: XCUIElement, _ description: String) {
        // Always taps at least once, even when the keyboard is already up for a previous field,
        // since that tap is what moves focus to this one.
        var attempts = 0
        repeat {
            element.tap()
            attempts += 1
        } while !app.keyboards.element.waitForExistence(timeout: Timeout.optional) && attempts < 3

        XCTAssertTrue(app.keyboards.element.exists, "Keyboard never came up for the \(description)")
    }

    private func holds(_ element: XCUIElement, _ text: String, secure: Bool) -> Bool {
        let value = element.value as? String
        // Secure fields report one bullet per character rather than the text itself.
        return secure ? value?.count == text.count : value == text
    }

    private func clear(_ element: XCUIElement) {
        let count = (element.value as? String)?.count ?? 0
        guard count > 0 else { return }
        element.tap()
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count + 2))
    }

    /// The keyboard tutorial sits where the keys would be and offers a single Continue button; the
    /// app's own Continue buttons never share the keyboard's frame, which is what tells them apart.
    private func dismissKeyboardTutorialIfPresent() {
        let keyboard = app.keyboards.element
        guard keyboard.exists else { return }
        let keyboardTop = keyboard.frame.minY - 100
        for container in [app, springboard] {
            let candidates = container.buttons.matching(NSPredicate(format: "label == 'Continue'"))
            if let button = candidates.allElementsBoundByIndex.first(where: { $0.frame.minY >= keyboardTop }) {
                button.tap()
                _ = app.keyboards.element.waitForExistence(timeout: Timeout.optional)
                return
            }
        }
    }

    @discardableResult
    func tapIfPresent(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    /// Taps a web element until whatever it opens is actually on screen.
    ///
    /// A tap aimed at the frontend is swallowed while the page is still settling, and the element
    /// stays exactly where it was rather than reporting anything, so the tap has to be repeated
    /// until its effect shows up.
    func tapWebElement(
        labelContaining text: String,
        until target: XCUIElement,
        timeout: TimeInterval,
        _ description: String
    ) {
        let element = webElement(labelContaining: text)
        wait(for: element, timeout: timeout, description)

        for _ in 0 ..< 3 {
            if element.isHittable {
                element.tap()
            }
            if isHittable(target, within: Timeout.optional) {
                return
            }
        }

        XCTFail("The \(description) did not open")
    }

    func isHittable(_ element: XCUIElement, within timeout: TimeInterval) -> Bool {
        let hittable = testCase.expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: element)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }

    /// An element of the frontend, matched on part of its accessibility label.
    ///
    /// The frontend's own copy is the only handle here, so matching stays loose: a sidebar entry
    /// carries a badge when there are pending updates or repairs, and an exact label would miss it.
    func webElement(labelContaining text: String) -> XCUIElement {
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
    func tapWebElement(labelContaining text: String, timeout: TimeInterval, _ description: String) {
        let element = webElement(labelContaining: text)
        wait(for: element, timeout: timeout, description)

        var scrolls = 0
        while !element.isHittable, scrolls < 3 {
            app.webViews.firstMatch.swipeUp()
            scrolls += 1
        }

        element.tap()
    }

    /// Taps a control until the screen carrying it goes away.
    ///
    /// `waitForExistence` returns on the first frame of a presentation, where the tap lands on the
    /// backdrop behind the still-moving screen and is swallowed. The tap reports success either way,
    /// so the only reliable signal is the screen actually leaving.
    func dismiss(_ element: XCUIElement, _ description: String) {
        for _ in 0 ..< 3 {
            guard element.exists else { return }
            if element.isHittable {
                element.tap()
            }
            if element.waitForNonExistence(timeout: Timeout.optional) {
                return
            }
        }

        XCTFail("The \(description) stayed on screen")
    }

    func allowSystemAlert(timeout: TimeInterval, _ description: String) {
        let allow = NSPredicate(format: "label BEGINSWITH[c] 'Allow'")
        guard let button = systemAlertButton(matching: allow, timeout: timeout) else {
            XCTFail("Timed out waiting for the \(description)")
            return
        }
        button.tap()
    }

    /// Answers an alert whichever way it offers, for prompts the flow does not depend on the answer
    /// to and which only have to be off the screen.
    @discardableResult
    func answerSystemAlertIfPresent(timeout: TimeInterval) -> Bool {
        guard let button = systemAlertButton(matching: NSPredicate(value: true), timeout: timeout) else {
            return false
        }
        button.tap()
        return true
    }

    /// Confirms the "X wants to open Y" prompt iOS raises for some cross-app URL scheme opens; nothing
    /// to do when the hop went through without one.
    @discardableResult
    func confirmOpeningOtherAppIfAsked() -> Bool {
        let open = NSPredicate(format: "label == 'Open'")
        guard let button = systemAlertButton(matching: open, timeout: Timeout.optional) else {
            return false
        }
        button.tap()
        return true
    }

    /// Allows the pasteboard read iOS asks about when this app was not the one that put the payload
    /// there and was not in the foreground moments before; nothing to do when no alert comes up.
    @discardableResult
    func allowPasteIfAsked() -> Bool {
        let allow = NSPredicate(format: "label == 'Allow Paste'")
        guard let button = systemAlertButton(matching: allow, timeout: Timeout.screen) else {
            return false
        }
        button.tap()
        return true
    }

    private func systemAlertButton(matching predicate: NSPredicate, timeout: TimeInterval) -> XCUIElement? {
        let hosted = springboard.alerts.firstMatch.buttons.matching(predicate).firstMatch
        if hosted.waitForExistence(timeout: timeout) {
            return hosted
        }

        // Not every iOS version presents these out of SpringBoard. An alert shown in-app has been
        // up since the wait above began, so this only needs long enough to resolve, not to wait for
        // it a second time.
        let inApp = app.alerts.firstMatch.buttons.matching(predicate).firstMatch
        return inApp.waitForExistence(timeout: Timeout.optional) ? inApp : nil
    }
}

extension XCUIElementQuery {
    subscript(identifier: AccessibilityIdentifier) -> XCUIElement {
        self[identifier.rawValue]
    }
}
