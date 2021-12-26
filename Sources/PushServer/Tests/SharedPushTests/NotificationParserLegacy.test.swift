import Foundation
import SharedPush
import XCTest

class NotificationParserLegacyTests: XCTestCase {
    private struct NotificationCase {
        var name: String = "(unknown)"
        var input: [String: Any]
        var headers: [String: Any]
        var payload: [String: Any]
        var rateLimit: Bool // unused in tests

        var expected: [String: Any] { [
            "headers": headers,
            "payload": payload,
        ] }

        init(jsonObject: Any) throws {
            let dict = try XCTUnwrap(jsonObject as? [String: Any])
            self.input = try XCTUnwrap(dict["input"] as? [String: Any])
            self.headers = try XCTUnwrap(dict["headers"] as? [String: Any])
            self.payload = try XCTUnwrap(dict["payload"] as? [String: Any])
            self.rateLimit = dict["headers"] as? Bool ?? true
        }
    }

    private var notificationCases: [NotificationCase]!

    override func setUpWithError() throws {
        super.setUp()

        let container = try XCTUnwrap(
            Bundle.module.url(forResource: "notification_test_cases", withExtension: "bundle")
        )
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: container, includingPropertiesForKeys: nil))

        notificationCases = try enumerator.allObjects
            .map { try XCTUnwrap($0 as? URL) }
            .filter { $0.pathExtension == "json" }
            .map { ($0.lastPathComponent, try Data(contentsOf: $0)) }
            .map { ($0.0, try JSONSerialization.jsonObject(with: $0.1, options: [])) }
            .map {
                var notificationCase = try NotificationCase(jsonObject: $0.1)
                notificationCase.name = $0.0
                return notificationCase
            }
        XCTAssertFalse(notificationCases.isEmpty)
    }

    func testAllCases() throws {
        let parser = LegacyNotificationParserImpl(pushSource: "<test-push-value>")

        for data in notificationCases {
            func prettyString(from object: [String: Any]) throws -> String {
                let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
                return try XCTUnwrap(String(data: data, encoding: .utf8))
            }

            let resultStruct = parser.result(from: data.input, defaultRegistrationInfo: [:])
            let result = ["headers": resultStruct.headers, "payload": resultStruct.payload]
            let resultString = try prettyString(from: result)
            let expected = data.expected
            let expectedString = try prettyString(from: expected)

            XCTAssertEqual(resultString, expectedString, data.name)
        }
    }
}
