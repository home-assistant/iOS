import Foundation
@testable import Shared
import Testing

/// Parsing a light's color attributes from the loosely typed attribute dictionary.
struct EntityColorAttributesParserTests {
    @Test func missingAttributesParseToNothing() {
        let parsed = EntityColorAttributesParser.parse(from: nil)
        #expect(parsed.colorMode == nil)
        #expect(parsed.rgbColor == nil)
        #expect(parsed.hsColor == nil)
    }

    @Test func typedArraysParseDirectly() {
        let parsed = EntityColorAttributesParser.parse(from: [
            "color_mode": "hs",
            "rgb_color": [255, 128, 0],
            "hs_color": [30.0, 100.0, 5.0],
        ])
        #expect(parsed.colorMode == "hs")
        #expect(parsed.rgbColor == [255, 128, 0])
        #expect(parsed.hsColor == [30, 100])
    }

    @Test func mixedArraysAreCoerced() {
        #expect(EntityColorAttributesParser.parseRGBColor(from: [NSNumber(value: 1), "2", 3] as [Any]) == [1, 2, 3])
        #expect(EntityColorAttributesParser.parseRGBColor(from: [1, "x", 3] as [Any]) == nil)
        #expect(EntityColorAttributesParser.parseRGBColor(from: "255,0,0") == nil)
        #expect(EntityColorAttributesParser.parseHSColor(from: [NSNumber(value: 10.5), "20"] as [Any]) == [10.5, 20])
        #expect(EntityColorAttributesParser.parseHSColor(from: [1.0, "nope"] as [Any]) == nil)
        #expect(EntityColorAttributesParser.parseHSColor(from: [1.0]) == nil)
        #expect(EntityColorAttributesParser.parseHSColor(from: nil) == nil)
    }
}
