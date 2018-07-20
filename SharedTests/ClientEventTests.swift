//
//  ClientEventTests.swift
//  HomeAssistantTests
//
//  Created by Stephan Vanterpool on 6/20/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import XCTest
import RealmSwift
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
