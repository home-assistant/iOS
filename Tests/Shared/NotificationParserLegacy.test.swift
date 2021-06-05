import Foundation
import XCTest
import ObjectMapper
import Shared

class NotificationParserLegacyTests: XCTestCase {
    private struct NotificationCase: ImmutableMappable {
        var name: String = "(unknown)"
        var input: [String: Any]
        var headers: [String: Any]
        var payload: [String: Any]
        var rateLimit: Bool // unused in tests

        var expected: [String: Any] { [
            "payload": [
                "apns": [
                    "headers": headers,
                    "payload": payload
                ]
            ]
        ] }

        init(map: Map) throws {
            self.input = try map.value("input")
            self.headers = try map.value("headers")
            self.payload = try map.value("payload")
            self.rateLimit = try map.value("rate_limit")
        }

        func mapping(map: Map) {
            input >>> map["input"]
            headers >>> map["headers"]
            payload >>> map["payload"]
            rateLimit >>> map["rate_limit"]
        }
    }

    private var notificationCases: [NotificationCase]!

    override func setUpWithError() throws {
        super.setUp()

        let container = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "notification_test_cases", withExtension: "bundle"))
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: container, includingPropertiesForKeys: nil))

        let mapper = Mapper<NotificationCase>()


        notificationCases = try enumerator.allObjects
            .map { try XCTUnwrap($0 as? URL) }
            .filter { $0.pathExtension == "json" }
            .map { ($0.lastPathComponent, try Data(contentsOf: $0)) }
            .map { ($0.0, try JSONSerialization.jsonObject(with: $0.1, options: [])) }
            .map {
                var notificationCase = try mapper.map(JSONObject: $0.1)
                notificationCase.name = $0.0
                return notificationCase
            }
        XCTAssertFalse(notificationCases.isEmpty)
    }

    func testAllCases() throws {
        for data in notificationCases {
            func prettyString(from object: [String: Any]) throws -> String {
                let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
                return try XCTUnwrap(String(data: data, encoding: .utf8))
            }

            let result = NotificationParserLegacy.result(from: data.input)
            let resultString = try prettyString(from: result)
            let expected = data.expected
            let expectedString = try prettyString(from: expected)

            XCTAssertEqual(resultString, expectedString, data.name)
        }
    }
}
