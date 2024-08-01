//
//  WatchContextTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 01/08/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import XCTest
@testable import Shared
final class WatchContextTests: XCTestCase {

    func testWatchContextCases() {
        XCTAssertEqual(WatchContext.allCases.count, 8)
        XCTAssertEqual(WatchContext.servers.rawValue, "servers")
        XCTAssertEqual(WatchContext.actions.rawValue, "actions")
        XCTAssertEqual(WatchContext.complications.rawValue, "complications")
        XCTAssertEqual(WatchContext.ssid.rawValue, "SSID")
        XCTAssertEqual(WatchContext.activeFamilies.rawValue, "activeFamilies")
        XCTAssertEqual(WatchContext.watchModel.rawValue, "watchModel")
        XCTAssertEqual(WatchContext.watchVersion.rawValue, "watchVersion")
        XCTAssertEqual(WatchContext.watchBattery.rawValue, "watchBattery")
    }
}
