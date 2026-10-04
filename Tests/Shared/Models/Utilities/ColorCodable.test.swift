@testable import Shared
import SwiftUI
import UIKit
import XCTest

final class ColorCodableTests: XCTestCase {
    private struct Wrapper: Codable {
        let color: Color
    }

    func testEncodesRGBComponents() throws {
        let data = try JSONEncoder().encode(Wrapper(color: Color(red: 1, green: 0.5, blue: 0)))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let color = try XCTUnwrap(object["color"] as? [String: Double])

        XCTAssertEqual(Set(color.keys), ["red", "green", "blue"])
        XCTAssertEqual(try XCTUnwrap(color["red"]), 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(color["green"]), 0.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(color["blue"]), 0, accuracy: 0.001)
    }

    func testDecodesRGBComponents() throws {
        let json = Data("{\"color\":{\"red\":0,\"green\":0.6,\"blue\":1}}".utf8)
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: json)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(UIColor(wrapper.color).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(red, 0, accuracy: 0.001)
        XCTAssertEqual(green, 0.6, accuracy: 0.001)
        XCTAssertEqual(blue, 1, accuracy: 0.001)
        XCTAssertEqual(alpha, 1, accuracy: 0.001)
    }

    func testDecodingMissingComponentThrows() {
        let json = Data("{\"color\":{\"red\":0,\"green\":0.6}}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Wrapper.self, from: json))
    }

    func testRoundTrip() throws {
        let original = Wrapper(color: Color(red: 0.2, green: 0.4, blue: 0.8))
        let decoded = try JSONDecoder().decode(Wrapper.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.color.hex(), original.color.hex())
    }
}
