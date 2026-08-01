import Foundation
@testable import Shared
import Testing

struct HAGestureActionTests {
    @Test func testDecodingKnownRawValueDecodesMatchingCase() throws {
        let decoded = try JSONDecoder().decode([HAGestureAction].self, from: Data("[\"showSidebar\"]".utf8))
        #expect(decoded == [.showSidebar])
    }

    @Test func testDecodingRemovedSmartBackFallsBackToBackPage() throws {
        let decoded = try JSONDecoder().decode([HAGestureAction].self, from: Data("[\"smartBack\"]".utf8))
        #expect(decoded == [.backPage])
    }

    @Test func testDecodingUnknownRawValueFallsBackToNone() throws {
        let decoded = try JSONDecoder().decode([HAGestureAction].self, from: Data("[\"somethingUnknown\"]".utf8))
        #expect(decoded == [.none])
    }
}
