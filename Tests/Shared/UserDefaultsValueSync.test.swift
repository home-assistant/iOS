@testable import Shared
import XCTest

class UserDefaultsValueSyncTests: XCTestCase {
    private var model: UserDefaultsValueSync<TestCodable>!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()

        userDefaults = UserDefaults()
        model = UserDefaultsValueSync<TestCodable>(settingsKey: "basicSync", userDefaults: userDefaults)
    }

    func testReuseKey() {
        var model2: UserDefaultsValueSync<TestCodable>? = UserDefaultsValueSync<TestCodable>(
            settingsKey: model.settingsKey
        )
        weak var weakSync1 = model2
        model2 = nil

        XCTAssertNil(weakSync1)

        // if KVO isn't set up correctly, this will crash
        model.value = .init(value: "new")
    }

    func testNotify() {
        var values = [TestCodable]()

        let cancellable = model.observe { value in
            values.append(value)
        }

        model.value = .init(value: "1")
        model.value = .init(value: "2")
        model.value = .init(value: "3")
        model.value = .init(value: "4")
        model.value = nil
        cancellable.cancel()
        model.value = .init(value: "5")

        XCTAssertEqual(values.map(\.value), ["1", "2", "3", "4"])
    }

    func testFailedGet() {
        userDefaults.set("moo".data(using: .utf8), forKey: model.settingsKey)
        XCTAssertNil(model.value)
    }

    func testFailedSet() {
        let failObject = TestCodable(value: "failed")
        failObject.failEncode = true

        model.value = .init(value: "base")
        model.value = failObject

        XCTAssertEqual(model.value?.value, "base")
    }
}

private class TestCodable: Codable {
    var value: String?
    var failEncode: Bool = false

    enum FailEncodeError: Error {
        case fail
    }

    func encode(to encoder: Encoder) throws {
        if failEncode {
            throw FailEncodeError.fail
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .value)
            try container.encode(failEncode, forKey: .failEncode)
        }
    }

    init(value: String?) {
        self.value = value
    }
}
