import XCTest

class HomeAssistantUITests: XCTestCase {
    override func setUp() {
        super.setUp()

        let app = XCUIApplication()
        continueAfterFailure = false

        // Enable Fastlane snapshots
        setupSnapshot(app, waitForAnimations: false)
        app.launch()

        let handler = addUIInterruptionMonitor(withDescription: "System Dialog") { alert -> Bool in
            alert.buttons.element(boundBy: 1).tap()
            return true
        }
        app.tap()
        removeUIInterruptionMonitor(handler)
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testScreenshots() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        /* let app = XCUIApplication()
         let web = app.webViews

         let sidebarToggle = web.buttons["Sidebar Toggle"]

         wait(for: sidebarToggle, timeout: 20)

         sidebarToggle.tap(withNumberOfTaps: 2, numberOfTouches: 1)
         web.links["App Configuration"].firstMatch.tap()

         // Map Notification Screenshot
         app.tables.cells["map_notification_test"].tap() */

        ensureMapNotification()

        snapshot("01MapContentExtension")

        XCTAssert(springboard.buttons.matching(identifier: "dismiss-expanded-button").firstMatch.exists)

        springboard.buttons.matching(identifier: "dismiss-expanded-button").firstMatch.tap()

        sleep(5)

        // Camera Notification Screenshot
        // app.tables.cells["camera_notification_test"].tap()

        ensureCameraNotification()

        snapshot("02CameraContentExtension")

        XCTAssert(springboard.buttons.matching(identifier: "dismiss-expanded-button").firstMatch.exists)

        springboard.buttons.matching(identifier: "dismiss-expanded-button").firstMatch.tap()

        snapshot("03Frontend")
    }

    func ensureMapNotification() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        let notification = springboard.otherElements["NotificationShortLookView"]
        XCTAssert(notification.waitForExistence(timeout: 10))
        notification.swipeDown()

        let notificationMap = springboard.maps.element(boundBy: 0)
        let notifPredicate = NSPredicate(format: "label CONTAINS 'New York'")
        let ensureNotifMapLoad = notificationMap.otherElements.matching(notifPredicate).element(boundBy: 0)

        // wait for the map to finish loading and zooming
        wait(for: ensureNotifMapLoad, timeout: 10)
        XCTAssertTrue(ensureNotifMapLoad.exists)

        let notifMap = springboard.otherElements.matching(identifier: "notification_map").element(boundBy: 0)
        XCTAssertTrue(notifMap.exists)
    }

    func ensureCameraNotification() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        let notification = springboard.otherElements["NotificationShortLookView"]
        XCTAssert(notification.waitForExistence(timeout: 20))
        notification.swipeDown()

        let expandedNotification = springboard.otherElements["camera_notification"]

        wait(for: expandedNotification, timeout: 10)

        let imageView = expandedNotification.images["camera_notification_imageview"]
        wait(for: imageView, timeout: 20)
        XCTAssertTrue(imageView.exists)
    }
}

extension XCTestCase {
    func wait(for duration: TimeInterval) {
        let waitExpectation = expectation(description: "Waiting")

        let when = DispatchTime.now() + duration
        DispatchQueue.main.asyncAfter(deadline: when) {
            waitExpectation.fulfill()
        }

        // We use a buffer here to avoid flakiness with Timer on CI
        waitForExpectations(timeout: duration + 0.5)
    }

    /// Wait for element to appear
    func wait(for element: XCUIElement, timeout duration: TimeInterval) {
        let predicate = NSPredicate(format: "exists == true")
        _ = expectation(for: predicate, evaluatedWith: element, handler: nil)

        // Here we don't need to call `waitExpectation.fulfill()`

        // We use a buffer here to avoid flakiness with Timer on CI
        waitForExpectations(timeout: duration + 0.5)
    }
}
