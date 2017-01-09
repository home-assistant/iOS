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
        snapshot("00Launch")
        let welcomeAlert = app.alerts["Welcome"]
        let myawesomeemailGmailComTextField = welcomeAlert.collectionViews.textFields["myawesomeemail@gmail.com"]
        myawesomeemailGmailComTextField.tap()
        myawesomeemailGmailComTextField.typeText("me@robbiet.us")
        welcomeAlert.buttons["OK"].tap()
        
        let tablesQuery2 = app.tables
        let tablesQuery = tablesQuery2
        tablesQuery.textFields["https://homeassistant.myhouse.com"].tap()
        tablesQuery2.cells.containing(.staticText, identifier:"URL").children(matching: .textField).element.typeText("privatedemo.home-assistant.io")
        let textValue = tablesQuery2.cells.containing(.staticText, identifier:"URL").children(matching: .textField).element.value as! String
        XCTAssert(textValue == "https://privatedemo.home-assistant.io")
        
        let connectStaticText = tablesQuery.staticTexts["Connect"]
        connectStaticText.tap()
        tablesQuery.staticTexts["Password"].tap()
        tablesQuery2.cells.containing(.staticText, identifier:"Password").children(matching: .secureTextField).element.typeText("demoprivate")
        connectStaticText.tap()
        app.navigationBars["Settings"].buttons["Done"].tap()

        snapshot("01GroupView", waitForLoadingIndicator: true)

        let tabBarsQuery = app.tabBars
        tabBarsQuery.buttons["All Switches"].tap()
        
        tablesQuery.staticTexts["Decorative Lights"].tap()
        snapshot("02SingleEntity")
        tablesQuery.switches["Decorative Lights"].tap()
        app.navigationBars["Decorative Lights"].buttons["All Switches"].tap()
        tabBarsQuery.buttons["More"].tap()
        snapshot("03ShowAllTabs")
        app.navigationBars["More"].buttons["Edit"].tap()
        app.navigationBars.buttons["Done"].tap()
        app.staticTexts["automations"].tap()
        tablesQuery.staticTexts["Notify Anne Therese is home"].tap()
        snapshot("04ShowAutomationEntity")


    }
}
