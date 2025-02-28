@testable import HomeAssistant

import XCTest

class ArraySafeSubcriptingTests: XCTestCase {
	func testSafeSubscript() {
		let array: [Int] = [1, 2, 3]
		
		XCTAssertEqual(array[safe: 0], 1)
		XCTAssertEqual(array[safe: 1], 2)
		XCTAssertEqual(array[safe: 2], 3)
	}
	
	func testSafeSubscriptOutOfBounds() {
		let array: [Int] = [1, 2, 3]
		
		XCTAssertNil(array[safe: -1])
		XCTAssertNil(array[safe: 3])
	}
}
