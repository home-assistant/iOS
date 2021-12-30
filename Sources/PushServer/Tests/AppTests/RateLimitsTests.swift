@testable import App
import XCTest
import XCTVapor

class RateLimitsTests: AbstractTestCase {
    private var now: Date!
    private var cache: FakeCache!
    private var rateLimits: RateLimitsImpl!

    override func setUpWithError() throws {
        try super.setUpWithError()

        now = Date()
        cache = .init(eventLoop: app.eventLoopGroup.next())
        rateLimits = .init(cache: cache, nowProvider: { [weak self] in self?.now ?? .init() })
    }

    func testExpirationDate() async throws {
        let expirationDate1 = await rateLimits.expirationDate(for: "token1")
        let expirationDate2 = await rateLimits.expirationDate(for: "token2")
        XCTAssertEqual(expirationDate1, expirationDate2)

        now = Calendar.current.date(byAdding: .day, value: 1, to: now, wrappingComponents: true)

        let expirationDate3 = await rateLimits.expirationDate(for: "token3")
        XCTAssertGreaterThan(expirationDate3, expirationDate2)

        let expected = Calendar.current.startOfDay(for: try XCTUnwrap(
            Calendar.current.date(byAdding: .day, value: 1, to: now, wrappingComponents: false)
        )).timeIntervalSince(now)
        XCTAssertGreaterThan(expected, 0)
        XCTAssertLessThan(expected, 86400)

        _ = try await rateLimits.increment(kind: .successful, for: "token4")
        XCTAssertEqual(cache.expirations[RateLimitsImpl.key(for: "token4")]?.seconds, Int(expected))
    }

    func testRateLimitGettingAndSetting() async throws {
        let unset = try await rateLimits.rateLimit(for: "token")
        XCTAssertEqual(unset, .init())

        let set = try await rateLimits.increment(kind: .successful, for: "token2")
        XCTAssertEqual(set.successful, 1)
    }
}
