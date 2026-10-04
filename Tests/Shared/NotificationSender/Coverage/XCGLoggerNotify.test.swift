import Foundation
@testable import Shared
import XCGLogger
import XCTest

final class XCGLoggerNotifyTests: XCTestCase {
    func testKeys() {
        XCTAssertEqual(XCGLogger.notifyUserInfoKey, "is_xcglogger_notify_category")
        XCTAssertEqual(XCGLogger.shouldNotifyUserDefaultsKey, "xcglogger_unnotifications")
    }

    func testNotifyIsANoOpWhileRunningTests() {
        XCTAssertTrue(Current.isRunningTests)

        var evaluations = 0
        func message() -> String {
            evaluations += 1
            return "message"
        }

        Current.Log.notify(message(), log: .info)

        XCTAssertEqual(evaluations, 0)
    }
}
