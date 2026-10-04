import Foundation
@testable import Shared
import XCTest

final class DataHexadecimalTests: XCTestCase {
    func testEncodesLowercasePaddedHex() {
        XCTAssertEqual(Data([0x00, 0x0A, 0xFF, 0x10]).hexadecimal, "000aff10")
        XCTAssertEqual(Data().hexadecimal, "")
    }

    func testDecodesHexString() {
        XCTAssertEqual(Data(hexadecimal: "000aff10"), Data([0x00, 0x0A, 0xFF, 0x10]))
        XCTAssertEqual(Data(hexadecimal: "ABcd"), Data([0xAB, 0xCD]))
        XCTAssertEqual(Data(hexadecimal: ""), Data())
    }

    func testDecodingIgnoresTrailingOddCharacter() {
        XCTAssertEqual(Data(hexadecimal: "abc"), Data([0xAB]))
    }

    func testDecodingInvalidCharactersFails() {
        XCTAssertNil(Data(hexadecimal: "zz"))
        XCTAssertNil(Data(hexadecimal: "00g1"))
    }

    func testStringHexadecimalRoundTrips() {
        let data = Data((0 ... 255).map { UInt8($0) })
        XCTAssertEqual(data.hexadecimal.hexadecimal, data)
        XCTAssertNil("xy".hexadecimal)
    }
}
