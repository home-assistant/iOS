import XCTest

/// Drives the app through the screens the end-to-end tests share, against a real Home Assistant:
/// onboarding from the welcome screen, the web login, and what follows on the frontend.
///
/// Instantiated by each test over its own launched `XCUIApplication`, so the steps can be combined
/// into flows that start the same way and diverge after, such as onboarding followed by a relaunch.
final class E2EFlow {
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

    let app: XCUIApplication
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    /// How long to linger before each tap and after each screen, for recordings meant to be watched rather than
    /// checked. Zero for the nightly tests.
    var stepDelay: TimeInterval = 0

    init(app: XCUIApplication) {
        self.app = app
    }

    /// Waits `stepDelay`, so a recording shows the screen before it changes.
    func pause() {
        guard stepDelay > 0 else { return }
        RunLoop.current.run(until: Date().addingTimeInterval(stepDelay))
    }

    /// Relaunches the app as a device with `vendorID`, which is what a backup restored onto other hardware looks
    /// like to it: the registrations were made under the identifier of the device the backup came from.
    func relaunch(asDevice vendorID: String) {
        app.terminate()
        app.launchArguments = Self.launchArguments + ["-E2E_VENDOR_IDENTIFIER", vendorID]
        app.launch()
    }

    /// Launch arguments every end-to-end run passes, before any flow-specific ones.
    ///
    /// Onboards with the release client ID rather than the debug one. Home Assistant allows the
    /// release iOS callback offline, but has to fetch `https://home-assistant.io/iOS/dev-auth` to
    /// allow the debug one, and it reads only the first 10 KB of that page, which no longer reaches
    /// the `redirect_uri` link tag. The debug pair is rejected with "Invalid redirect URI", so the
    /// flow could never log in.
    static let launchArguments = ["-FASTLANE_SNAPSHOT", "YES"]

    /// Onboards from the welcome screen to the frontend, with every permission prompt answered.
    func onboard() {
        connectToInstance()
        logIn()
        nameDevice()
        answerPermissions()
        grantNotificationPermission()
    }

    /// Answers the screen a device restored from another one's backup is shown by setting the device
    /// up as a new one: signs in again through the login sheet and waits for the frontend to return.
    func setUpAsNewDevice() {
        tap(
            app.buttons[.restoredRegistrationsNewDevice],
            timeout: Timeout.screen,
            "restored registrations screen"
        )
        logIn(in: webViewShowingLogin(timeout: Timeout.frontend))
        // The screen closes once every server is registered; the login sheet goes with it.
        waitUntilGone(
            app.buttons[.restoredRegistrationsNewDevice],
            timeout: Timeout.frontend,
            "restored registrations screen"
        )
        wait(for: app.webViews.firstMatch, timeout: Timeout.frontend, "frontend after registering")
    }

    /// Answers the same screen by replacing the old device: confirms, and waits for the frontend to return.
    func replaceOldDevice() {
        tap(app.buttons[.restoredRegistrationsReplace], timeout: Timeout.screen, "restored registrations screen")
        tap(confirmationButton(labelContaining: "Replace"), timeout: Timeout.screen, "replace confirmation")
        waitUntilGone(
            app.buttons[.restoredRegistrationsReplace],
            timeout: Timeout.frontend,
            "restored registrations screen"
        )
        wait(for: app.webViews.firstMatch, timeout: Timeout.frontend, "frontend after replacing")
    }

    /// Starts setting up as a new device, then cancels the login, which leaves the server for the next launch.
    func cancelSettingUpAsNewDevice() {
        tap(
            app.buttons[.restoredRegistrationsNewDevice],
            timeout: Timeout.screen,
            "restored registrations screen"
        )
        wait(for: webViewShowingLogin(timeout: Timeout.frontend), timeout: Timeout.frontend, "login sheet")
        tap(app.buttons[.loginCancel], timeout: Timeout.screen, "login cancel button")
        waitUntilGone(
            app.buttons[.restoredRegistrationsNewDevice],
            timeout: Timeout.frontend,
            "restored registrations screen"
        )
    }

    /// From the frontend, opens the native settings, then the first server's settings.
    func openServerSettingsFromFrontend() {
        openNativeSettingsFromFrontend()
        tap(app.descendants(matching: .any)[.settingsServerRow].firstMatch, timeout: Timeout.screen, "server row")
    }

    /// Registers as a new device from the server's settings: confirms, signs in again, and waits for the row to
    /// be ready again.
    func registerAsNewDeviceFromSettings() {
        let row = app.buttons[.connectionSettingsRegisterAsNewDevice]
        scrollTo(row, "register as new device row")
        tap(row, timeout: Timeout.screen, "register as new device row")
        tap(confirmationButton(labelContaining: "Register"), timeout: Timeout.screen, "register confirmation")
        logIn(in: webViewShowingLogin(timeout: Timeout.frontend))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: row)
        XCTAssertEqual(
            XCTWaiter().wait(for: [enabled], timeout: Timeout.frontend),
            .completed,
            "The register as new device row did not finish"
        )
        pause()
    }

    /// A button of the confirmation dialog on screen, which iOS shows as a sheet, by part of its label.
    func confirmationButton(labelContaining text: String) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        return app.sheets.firstMatch.buttons.matching(predicate).firstMatch
    }

    /// Swipes up until `element` can be tapped, for rows further down a list than the screen shows.
    func scrollTo(_ element: XCUIElement, _ description: String) {
        for _ in 0 ..< 8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Could not scroll to the \(description)")
    }

    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval, _ description: String) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [gone], timeout: timeout),
            .completed,
            "The \(description) stayed on screen"
        )
        pause()
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

    /// Logs in through `loginWebView`, or the first web view when none is given, as during onboarding.
    func logIn(in loginWebView: XCUIElement? = nil) {
        let webView = loginWebView ?? app.webViews.firstMatch
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
        tapIfPresent(webElement(labelContaining: "authorize", in: webView), timeout: Timeout.optional)
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
        // Deliberately runs in the same session that just onboarded: that is the case the settings stack
        // used to crash in. It was nested inside onboarding's own `NavigationStack`, and SwiftUI raised an
        // unexpected error from `NavigationColumnState.boundPathChange` as soon as
        // `AppSettingsPresenter.pushPath` gained its first element (and, on iOS 16, at the very first
        // layout). The stack now wraps only the frontend, so nothing is nested and no relaunch is needed.

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

    /// The web view with a login form on it. A sheet opens the login over the frontend, whose own
    /// web view stays in the hierarchy ahead of it, so the first web view is not the one to type into.
    func webViewShowingLogin(timeout: TimeInterval) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let webViews = app.webViews.allElementsBoundByIndex
            if let webView = webViews.last(where: { $0.textFields.firstMatch.exists }) {
                return webView
            }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        } while Date() < deadline

        XCTFail("Timed out waiting for a web view showing a login form")
        return app.webViews.firstMatch
    }

    // MARK: - Helpers

    func wait(for element: XCUIElement, timeout: TimeInterval, _ description: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Timed out waiting for the \(description)")
    }

    func tap(_ element: XCUIElement, timeout: TimeInterval, _ description: String) {
        wait(for: element, timeout: timeout, description)
        pause()
        element.tap()
    }

    /// Types into a field, waiting for it to actually take keyboard focus first.
    ///
    /// A tap on a web view field does not focus it synchronously: the page has to handle the touch
    /// and move focus itself. Typing before that fails outright with "Neither element nor any
    /// descendant has keyboard focus", so the tap is repeated until the keyboard is up.
    func type(_ text: String, into element: XCUIElement, _ description: String) {
        // Always taps at least once, even when the keyboard is already up for a previous field,
        // since that tap is what moves focus to this one.
        var attempts = 0
        repeat {
            element.tap()
            attempts += 1
        } while !app.keyboards.element.waitForExistence(timeout: Timeout.optional) && attempts < 3

        XCTAssertTrue(app.keyboards.element.exists, "Keyboard never came up for the \(description)")
        // The keyboard is still sliding in when it first exists; keys pressed before it settles are dropped.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        element.typeText(text)

        // A web field that still lost characters is cleared and typed into once more.
        if element.elementType != .secureTextField, (element.value as? String) != text,
           let typed = element.value as? String, !typed.isEmpty {
            element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
            element.typeText(text)
        }
    }

    @discardableResult
    func tapIfPresent(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    /// An element of the frontend, matched on part of its accessibility label.
    ///
    /// The frontend's own copy is the only handle here, so matching stays loose: a sidebar entry
    /// carries a badge when there are pending updates or repairs, and an exact label would miss it.
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
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }

    /// The element of `webView`, else of the first web view, whose label contains `text`.
    func webElement(labelContaining text: String, in webView: XCUIElement? = nil) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let webView = webView ?? app.webViews.firstMatch

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

    /// Allows whatever the alert asks for. The location alert lists "Allow Once" first, which lasts
    /// only until the app is next launched, so the lasting "While Using" answer is taken when offered.
    func allowSystemAlert(timeout: TimeInterval, _ description: String) {
        let allow = NSPredicate(format: "label BEGINSWITH[c] 'Allow'")
        guard let button = systemAlertButton(matching: allow, timeout: timeout) else {
            XCTFail("Timed out waiting for the \(description)")
            return
        }
        let whileUsing = NSPredicate(format: "label CONTAINS[c] 'While Using'")
        let lasting = systemAlertButton(matching: whileUsing, timeout: 1)
        (lasting ?? button).tap()
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

    func systemAlertButton(matching predicate: NSPredicate, timeout: TimeInterval) -> XCUIElement? {
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

/// Looks elements up by the identifiers the app compiles in, for every end-to-end test.
extension XCUIElementQuery {
    subscript(identifier: AccessibilityIdentifier) -> XCUIElement {
        self[identifier.rawValue]
    }
}
