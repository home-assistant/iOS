//
//  ClientEventTests.swift
//  HomeAssistantTests
//
//  Created by Stephan Vanterpool on 6/20/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import XCTest
import RealmSwift
import UserNotifications
@testable import Shared

class ClientEventTests: XCTestCase {
    var store: ClientEventStore!
    override func setUp() {
        super.setUp()
        Current.realm = Realm.mock
        self.store = ClientEventStore()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testStartsEmpty() {
        XCTAssertEqual(0, store.getEvents().count)
    }

    func testNotificationTitleForNotificationWithoutTitle() {
        let mutableContent = UNMutableNotificationContent()
        let alert = "House mode changed to away"
        let expectedTitle = "Received Notification: \(alert)"
        mutableContent.userInfo = [ "aps" : ["alert": alert, "sound": "default:"]]
        let content = mutableContent as UNNotificationContent
        XCTAssertEqual(content.clientEventTitle, expectedTitle)
    }

    func testNotificationTitleForNotificationWithATitle() {
        let mutableContent = UNMutableNotificationContent()
        let alert = "House mode changed to away"
        mutableContent.title = "Home Assistant Notification"
        mutableContent.subtitle = "Fake Sub"
        mutableContent.userInfo = [ "aps": ["alert": alert, "sound": "default:"]]

        let expectedTitle = "Received Notification: \(mutableContent.title) - \(mutableContent.subtitle)"
        let content = mutableContent as UNNotificationContent
        XCTAssertEqual(content.clientEventTitle, expectedTitle)
    }

    func testUnknownNotification() {
        let mutableContent = UNMutableNotificationContent()
        mutableContent.userInfo = [ "aps": ["sound": "default:"]]

        let expectedTitle = "Received a Push Notification"
        let content = mutableContent as UNNotificationContent
        XCTAssertEqual(content.clientEventTitle, expectedTitle)
    }

    func testCanWriteClientEvent() {
        let event = ClientEvent(text: "Yo", type: .notification)
        self.store.addEvent(event)
        XCTAssertEqual(1, store.getEvents().count)
    }

    func testEventWrittenCorrectly() {
        let date = Date()
        Current.date = { date }
        let event = ClientEvent(text: "Yo", type: .notification)
        self.store.addEvent(event)
        let retrieved = self.store.getEvents().first
        XCTAssertEqual(retrieved?.text, "Yo")
        XCTAssertEqual(retrieved?.type, .notification)
        XCTAssertEqual(retrieved?.date, date)
    }

    func testCanClearEvents() {
        let event = ClientEvent(text: "Yo", type: .notification)
        self.store.addEvent(event)
        XCTAssertEqual(1, store.getEvents().count)
        self.store.clearAllEvents()
    }
}
