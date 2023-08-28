//
//  WatchAssistServiceTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 28/08/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import XCTest
import Shared

final class WatchAssistServiceTests: XCTestCase {
    private var sut: WatchAssistService!
    private var mockAssistWrapper: MockWatchAssistIntentWrapping!

    override func setUp() {
        super.setUp()
        mockAssistWrapper = MockWatchAssistIntentWrapping()
        Current.watchAssistWrapper = mockAssistWrapper
        sut = WatchAssistService()
    }

    override func tearDown() {
        super.tearDown()
        sut = nil
        mockAssistWrapper = nil
    }

    func test_handle_receivesReplies() {
        // Given
        let expectation = XCTestExpectation(description: "Message closure")

        // When/Then
        sut.handle(message: .init(identifier: "123", reply: { message in
            XCTAssertNotNil(message.content)
            expectation.fulfill()
        }))

        wait(for: [expectation], timeout: 5)
    }

    func test_handle_receivesRepliesBasedOnAssist() {
        // Given
        let expectedInputText = "This is an input text"
        let expectedAnswer = "This is a display string"
        mockAssistWrapper.handleCompletionData = (expectedInputText, .success(result: .init(identifier: "123", display: expectedAnswer, pronunciationHint: nil)))
        let expectation = XCTestExpectation(description: "Message closure")

        // When
        sut.handle(message: .init(identifier: "123", content: ["Input": Data()], reply: { message in
            // swiftlint:disable force_cast
            XCTAssertEqual(message.content["answer"] as! String, expectedAnswer)
            XCTAssertEqual(message.content["inputText"] as! String, expectedInputText)
            // swiftlint:enable force_cast
            expectation.fulfill()
        }))

        wait(for: [expectation], timeout: 5)
    }

    func test_handle_receivesErrorReply_whenContentIsNil() {
        // Given
        let expectedAnswer = NSLocalizedString("Couldn't read input text", comment: "")
        let expectation = XCTestExpectation(description: "Message closure")

        // When
        sut.handle(message: .init(identifier: "123", content: ["Input": nil], reply: { message in
            // swiftlint:disable force_cast
            XCTAssertEqual(message.content["answer"] as! String, expectedAnswer)
            XCTAssertNil(message.content["inputText"] as? String)
            // swiftlint:enable force_cast
            expectation.fulfill()
        }))

        wait(for: [expectation], timeout: 5)

    }
}
