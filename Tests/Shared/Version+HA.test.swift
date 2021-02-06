import Foundation
@testable import Shared
import Version
import XCTest

class VersionHATests: XCTestCase {
    func testDevWithoutPatch() throws {
        let string = "0.112.dev0"
        let version = try Version(hassVersion: string)
        XCTAssertEqual(version.major, 0)
        XCTAssertEqual(version.minor, 112)
        XCTAssertNil(version.patch)
        XCTAssertEqual(version.prerelease, "dev0")
    }

    func testDevWithPatch() throws {
        let string = "0.112.0.dev0"
        let version = try Version(hassVersion: string)
        XCTAssertEqual(version.major, 0)
        XCTAssertEqual(version.minor, 112)
        XCTAssertEqual(version.patch, 0)
        XCTAssertEqual(version.prerelease, "dev0")
    }

    func testBetaWithoutPatch() throws {
        let string = "0.106b1"
        let version = try Version(hassVersion: string)
        XCTAssertEqual(version.major, 0)
        XCTAssertEqual(version.minor, 106)
        XCTAssertNil(version.patch)
        XCTAssertEqual(version.prerelease, "b1")
    }

    func testBetaWithPatch() throws {
        let string = "0.106.1b1"
        let version = try Version(hassVersion: string)
        XCTAssertEqual(version.major, 0)
        XCTAssertEqual(version.minor, 106)
        XCTAssertEqual(version.patch, 1)
        XCTAssertEqual(version.prerelease, "b1")
    }

    func testNormalWithoutPatch() throws {
        let string = "0.111"
        let version = try Version(hassVersion: string)
        XCTAssertEqual(version.major, 0)
        XCTAssertEqual(version.minor, 111)
        XCTAssertNil(version.patch)
        XCTAssertNil(version.prerelease)
    }

    func testNormalWithPatch() throws {
        let string = "0.111.1"
        let version = try Version(hassVersion: string)
        XCTAssertEqual(version.major, 0)
        XCTAssertEqual(version.minor, 111)
        XCTAssertEqual(version.patch, 1)
        XCTAssertNil(version.prerelease)
    }

    func testInvalid() {
        let string = "meow"
        XCTAssertThrowsError(try Version(hassVersion: string))
    }
}
