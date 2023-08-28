//
//  WatchAssistServiceTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 28/08/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import XCTest
@testable import Shared
final class WatchAssistServiceTests: XCTestCase {
    private var sut: WatchAssistService!

    override func setUp() {
        super.setUp()
        sut = WatchAssistService()
    }

    override func tearDown() {
        super.tearDown()
        sut = nil
    }

    func test_message_receivesReplies() {
        // Given
        let expectation = XCTestExpectation(description: "Message closure")

        // When/Then
        sut.handle(message: .init(identifier: "123", reply: { message in
            XCTAssertNotNil(message.content)
            expectation.fulfill()
        }))

        wait(for: [expectation], timeout: 5)
    }
}
