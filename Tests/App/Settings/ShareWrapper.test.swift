import Foundation
@testable import HomeAssistant
import Testing

struct ShareWrapperTests {
    @Test func urlConvenienceSharesJustThatURL() throws {
        let url = try #require(URL(string: "https://example.com/export.json"))
        let wrapper = ShareWrapper(url: url)

        #expect(wrapper.items.count == 1)
        #expect(wrapper.items.first as? URL == url)
    }

    @Test func everyWrapperPresentsAgain() {
        let first = ShareWrapper(items: ["same"])
        let second = ShareWrapper(items: ["same"])

        #expect(first.id != second.id)
    }
}
