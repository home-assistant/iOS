import APNS
@testable import App
import Foundation
import SharedPush
import XCTest
import XCTVapor

final class RateLimitsControllerTests: AbstractTestCase {
    private var cache: FakeCache!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cache = .init(eventLoop: app.eventLoopGroup.next())
        app.rateLimits.cache = cache
    }

    func testMissingToken() throws {
        for body in [
            "{}",
            #"{"push_token": ""}"#,
        ] {
            try app.test(.POST, "rate_limits/check", beforeRequest: { req in
                try req.content.encode(body, as: .plainText)
                req.headers.replaceOrAdd(name: .contentType, value: "application/json")
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testValues() throws {
        cache.values[RateLimitsImpl.key(for: "token")] = RateLimitsValues(
            successful: 3,
            errors: 4
        )

        try app.test(.POST, "rate_limits/check", beforeRequest: { req in
            try req.content.encode(RateLimitsGetInput(pushToken: "token"))
        }, afterResponse: { res in
            let json = (try? JSONSerialization.jsonObject(with: res.body) as? [String: Any]) ?? [:]
            XCTAssertEqual(json["target"] as? String, "token")

            let sub = (json["rate_limits"] as? [String: Any]) ?? [:]

            XCTAssertEqual(sub["successful"] as? Int, 3)
            XCTAssertEqual(sub["errors"] as? Int, 4)
            XCTAssertEqual(sub["maximum"] as? Int, RateLimitsValues.dailyMaximum)
            XCTAssertEqual(sub["remaining"] as? Int, RateLimitsValues.dailyMaximum - 7)
        })
    }
}
