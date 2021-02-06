import Foundation
@testable import Shared
import XCTest

class WatchBackgroundRefreshSchedulerTests: XCTestCase {
    private var scheduler: WatchBackgroundRefreshScheduler!

    override func setUp() {
        super.setUp()

        scheduler = WatchBackgroundRefreshScheduler()
    }

    private struct TestCase {
        let currentMinute: Int
        let expectedMinute: Int
    }

    private var testCases: [TestCase] {
        var testCases = [TestCase]()

        for minute in 0 ..< 15 {
            testCases.append(.init(currentMinute: minute, expectedMinute: 15))
        }

        for minute in 15 ..< 30 {
            testCases.append(.init(currentMinute: minute, expectedMinute: 30))
        }

        for minute in 30 ..< 45 {
            testCases.append(.init(currentMinute: minute, expectedMinute: 45))
        }

        for minute in 45 ..< 60 {
            testCases.append(.init(currentMinute: minute, expectedMinute: 60))
        }

        return testCases
    }

    func testTestCases() {
        // 2020-10-10 @ 10:00:00 UTC
        let baseDate = Date(timeIntervalSince1970: 1_602_324_000)

        let calendar = Calendar.current
        let baseComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: baseDate
        )

        func with(minute: Int) -> Date {
            var components = baseComponents
            components.minute = minute
            return calendar.date(from: components)!
        }

        for testCase in testCases {
            Current.date = { with(minute: testCase.currentMinute) }
            let date = scheduler.nextFireDate()
            XCTAssertEqual(date, with(minute: testCase.expectedMinute))
        }
    }
}
