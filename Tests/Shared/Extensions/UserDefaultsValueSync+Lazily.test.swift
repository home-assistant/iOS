import Foundation
import HAKit
@testable import Shared
import XCTest

/// `lazily(in:settingsKey:)` stands in for `lazy var` where readers race from several threads, so
/// every caller must end up with the one instance.
final class UserDefaultsValueSyncLazilyTests: XCTestCase {
    func testBuildsTheSyncOnceAndHandsItToEveryCaller() {
        let storage = HAProtected<UserDefaultsValueSync<Int>?>(value: nil)

        let first = UserDefaultsValueSync<Int>.lazily(in: storage, settingsKey: "lazily-test-shared")
        let second = UserDefaultsValueSync<Int>.lazily(in: storage, settingsKey: "lazily-test-shared")

        XCTAssertTrue(first === second)
        XCTAssertEqual(first.settingsKey, "lazily-test-shared")
        XCTAssertTrue(storage.read { $0 } === first)
    }

    func testConcurrentFirstAccessesAgreeOnOneInstance() {
        let storage = HAProtected<UserDefaultsValueSync<Int>?>(value: nil)
        let seen = HAProtected<Set<ObjectIdentifier>>(value: [])

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            let sync = UserDefaultsValueSync<Int>.lazily(in: storage, settingsKey: "lazily-test-concurrent")
            seen.mutate { $0.insert(ObjectIdentifier(sync)) }
        }

        XCTAssertEqual(seen.read { $0.count }, 1)
    }
}
