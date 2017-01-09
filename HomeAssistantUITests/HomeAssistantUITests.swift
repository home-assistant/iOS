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
        print("TEST EXAMPLE")
        print("RUN CONFIGURATION")
        let app = XCUIApplication()
        let tabBarsQuery = app.tabBars
        let tablesQuery2 = app.tables
        let tablesQuery = tablesQuery2
//        snapshot("0Launch")
//        app.alerts["Welcome"].collectionViews.textFields["myawesomeemail@gmail.com"].typeText("me@robbiet.us\r")
//
//        tablesQuery.textFields["https://homeassistant.myhouse.com"].tap()
//        tablesQuery2.cells.containing(.staticText, identifier:"URL").children(matching: .textField).element.typeText("privatedemo.home-assistant.io")
//        let textValue = tablesQuery2.cells.containing(.staticText, identifier:"URL").children(matching: .textField).element.value as! String
//        XCTAssert(textValue == "https://privatedemo.home-assistant.io")
//
//        let connectStaticText = tablesQuery.staticTexts["Connect"]
//        connectStaticText.tap()
//        tablesQuery.staticTexts["Password"].tap()
//        tablesQuery2.cells.containing(.staticText, identifier:"Password").children(matching: .secureTextField).element.typeText("demoprivate")
//        snapshot("01Connection")
//        connectStaticText.tap()
//        app.alerts["Connected"].buttons["OK"].tap()
        print("INSPECTENTITIES")

        snapshot("2DefaultGroupView")

        tabBarsQuery.buttons["All Switches"].tap()

        tablesQuery.staticTexts["AC"].tap()
        tablesQuery.switches["AC"].tap()
        snapshot("3SingleEntity")
        app.navigationBars["AC"].buttons["All Switches"].tap()
        snapshot("3SingleEntityOn")
        app.tabBars.buttons["people"].tap()
        tabBarsQuery.buttons["All Devices"].tap()
        app.tables.staticTexts["Anne Therese"].tap()
        app.navigationBars["45.8601, -119.6936"].buttons["All Devices"].tap()
        tabBarsQuery.buttons["All Lights"].tap()
        
        tablesQuery.staticTexts["Ceiling Lights"].tap()
        tablesQuery.switches["Ceiling Lights"].tap()

    }
}
