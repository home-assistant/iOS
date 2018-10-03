//
//  HomeAssistantUITests.swift
//  HomeAssistantUITests
//
//  Created by Robbie Trencheny on 3/25/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import XCTest

class HomeAssistantUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        let app = XCUIApplication()
        continueAfterFailure = false

        // Enable Fastlane snapshots
        setupSnapshot(app)
        XCUIApplication().launch()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        
        let app = XCUIApplication()

        let tablesQuery = app.tables

        let toolbar = app.toolbars["Toolbar"].children(matching: .other).element.children(matching: .other).element.children(matching: .button)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        if toolbar.allElementsBoundByIndex.count == 2 {
            toolbar.element(boundBy: 1).tap()

            tablesQuery.children(matching: .other)["STATUS"].children(matching: .other)["STATUS"].swipeUp()
            app/*@START_MENU_TOKEN@*/.tables.containing(.cell, identifier:"1").element/*[[".tables.containing(.other, identifier:\"Don't use these if you don't know what you are doing!\").element",".tables.containing(.other, identifier:\"DEVELOPER OPTIONS\").element",".tables.containing(.other, identifier:\"Device ID is the identifier used when sending location updates to Home Assistant, as well as the target to send push notifications to.\").element",".tables.containing(.cell, identifier:\"0\").element",".tables.containing(.cell, identifier:\"1\").element"],[[[-1,4],[-1,3],[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
            tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Enable location tracking"]/*[[".cells.staticTexts[\"Enable location tracking\"]",".staticTexts[\"Enable location tracking\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

            let allowBtn = springboard.buttons["Always Allow"]
            if allowBtn.exists {
                allowBtn.tap()
            }

            let enableNotificationsStaticText = tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Enable notifications"]/*[[".cells.staticTexts[\"Enable notifications\"]",".staticTexts[\"Enable notifications\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
            enableNotificationsStaticText.tap()
            enableNotificationsStaticText.tap()

            addUIInterruptionMonitor(withDescription: "Allow push") { (alerts) -> Bool in
                if(alerts.buttons["Allow"].exists){
                    alerts.buttons["Allow"].tap();
                }
                return true;
            }

            XCUIApplication().tap()

            app.navigationBars["Settings"].buttons["Done"].tap()
        }

        snapshot("0Launch")

        app.toolbars["Toolbar"].children(matching: .other).element.children(matching: .other).element.children(matching: .button).element(boundBy: 1).tap()

        // Device Map Screenshot

        let map = app.maps.element(boundBy: 0)
        let predicate = NSPredicate(format: "label CONTAINS 'San Francisco'")
        let ensureMapLoad = map.otherElements.matching(predicate).element(boundBy: 0)

        // wait for the map to finish loading and zooming
        wait(for: ensureMapLoad, timeout: 10)
        XCTAssertTrue(ensureMapLoad.exists)

        let picard = app.otherElements.matching(identifier: "device_tracker.static_picard").element(boundBy: 0)
        XCTAssertTrue(picard.exists)

        snapshot("02Map")

        app.navigationBars["Devices & Zones"].buttons["Done"].tap()

        toolbar.element(boundBy: 3).tap()

        app.tables/*@START_MENU_TOKEN@*/.staticTexts["iOS Notify Platform Loaded"]/*[[".cells.staticTexts[\"iOS Notify Platform Loaded\"]",".staticTexts[\"iOS Notify Platform Loaded\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeUp()

        // Map Notification Screenshot
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Show map content extension"]/*[[".cells.staticTexts[\"Show map content extension\"]",".staticTexts[\"Show map content extension\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        ensureMapNotification()

        snapshot("02MapContentExtension")

        XCTAssert(springboard.buttons["Dismiss"].firstMatch.exists)

        springboard.buttons["Dismiss"].firstMatch.tap()

        // Camera Notification Screenshot
        // tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Show camera content extension"]/*[[".cells.staticTexts[\"Show camera content extension\"]",".staticTexts[\"Show camera content extension\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        // ensureCameraNotification()

        // snapshot("04CameraContentExtension")
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
        XCTAssert(notification.waitForExistence(timeout: 10))
        notification.swipeDown()

        for element in springboard.otherElements.allElementsBoundByIndex {
            print("ELM ID", element.identifier)
        }

        print("springboard.images", springboard.images.count, springboard.images)

        let camera = springboard.otherElements.matching(identifier: "camera_notification_imageview").element(boundBy: 0)
        wait(for: camera, timeout: 10)
        XCTAssertTrue(camera.exists)
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
        let _ = expectation(for: predicate, evaluatedWith: element, handler: nil)

        // Here we don't need to call `waitExpectation.fulfill()`

        // We use a buffer here to avoid flakiness with Timer on CI
        waitForExpectations(timeout: duration + 0.5)
    }
}
