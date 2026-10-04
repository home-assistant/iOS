import Foundation
@testable import Shared
import XCTest

final class LocalPushManagerStateTests: XCTestCase {
    private func roundTrip(_ state: LocalPushManager.State) throws -> LocalPushManager.State {
        let data = try JSONEncoder().encode(state)
        return try JSONDecoder().decode(LocalPushManager.State.self, from: data)
    }

    private func json(_ state: LocalPushManager.State) throws -> [String: Any] {
        let data = try JSONEncoder().encode(state)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testIncrementFromEstablishingStartsCounting() {
        var state = LocalPushManager.State.establishing
        state.increment()
        XCTAssertEqual(state, .available(received: 1))
    }

    func testIncrementFromUnavailableUsesGivenCount() {
        var state = LocalPushManager.State.unavailable
        state.increment(by: 3)
        XCTAssertEqual(state, .available(received: 3))
    }

    func testIncrementWhileAvailableAccumulates() {
        var state = LocalPushManager.State.available(received: 4)
        state.increment()
        state.increment(by: 2)
        XCTAssertEqual(state, .available(received: 7))
    }

    func testEncodesPrimitiveAndCount() throws {
        let establishing = try json(.establishing)
        XCTAssertEqual(establishing["primitive"] as? String, "establishing")
        XCTAssertTrue(establishing["count"] == nil || establishing["count"] is NSNull)

        let unavailable = try json(.unavailable)
        XCTAssertEqual(unavailable["primitive"] as? String, "unavailable")

        let available = try json(.available(received: 5))
        XCTAssertEqual(available["primitive"] as? String, "available")
        XCTAssertEqual(available["count"] as? Int, 5)
    }

    func testRoundTripsEveryState() throws {
        XCTAssertEqual(try roundTrip(.establishing), .establishing)
        XCTAssertEqual(try roundTrip(.unavailable), .unavailable)
        XCTAssertEqual(try roundTrip(.available(received: 0)), .available(received: 0))
        XCTAssertEqual(try roundTrip(.available(received: 42)), .available(received: 42))
    }

    func testDecodingAvailableWithoutCountDefaultsToZero() throws {
        let data = Data("{\"primitive\":\"available\",\"count\":null}".utf8)
        let state = try JSONDecoder().decode(LocalPushManager.State.self, from: data)
        XCTAssertEqual(state, .available(received: 0))
    }

    func testDecodingUnknownPrimitiveThrows() {
        let data = Data("{\"primitive\":\"bogus\",\"count\":null}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(LocalPushManager.State.self, from: data))
    }
}
