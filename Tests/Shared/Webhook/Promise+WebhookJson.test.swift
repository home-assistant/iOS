import PromiseKit
@testable import Shared
import Sodium
import XCTest

class PromiseWebhookJsonTests: XCTestCase {
    private static var secret: [UInt8]!

    override class func setUp() {
        super.setUp()

        let sodium = Sodium()
        secret = (0 ..< sodium.secretBox.KeyBytes)
            .map { _ in UInt8.random(in: 0 ..< UInt8.max) }
    }

    static func encryptedResponse(data: Data) throws -> Data {
        let sodium = Sodium()
        let encryptedData: Bytes? = sodium.secretBox.seal(
            message: data.map { UInt8($0) },
            secretKey: .init(secret)
        )

        XCTAssertNotNil(encryptedData)

        let json: [String: Any] = [
            "encrypted": true,
            "encrypted_data": encryptedData.flatMap { sodium.utils.bin2base64($0, variant: .ORIGINAL) } ?? "",
        ]

        print("json: \(json)")

        let data = try JSONSerialization.data(withJSONObject: json, options: [])

        return data
    }

    func testUnencryptedNilData() {
        let promise = Promise<Data?>.value(nil)
        let json = promise.webhookJson(secretGetter: { nil })
        XCTAssertThrowsError(try hang(json)) { error in
            if case WebhookJsonParseError.empty = error {
                // pass
            } else {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testUnencryptedEmptyData() {
        let promise = Promise<Data?>.value(Data())
        let json = promise.webhookJson(secretGetter: { nil })
        XCTAssertNotNil(try hang(json))
    }

    func testUnencryptedStatus204() {
        let promise = Promise<Data>.value(String("abcdefg").data(using: .utf8)!)
        let json = promise.webhookJson(statusCode: 204, secretGetter: { nil })
        XCTAssertNotNil(try hang(json))
    }

    func testUnencryptedStatus205() {
        let promise = Promise<Data>.value(String("abcdefg").data(using: .utf8)!)
        let json = promise.webhookJson(statusCode: 205, secretGetter: { nil })
        XCTAssertNotNil(try hang(json))
    }

    func testUnencryptedStatus404() {
        let promise = Promise<Data>.value(String("abcdefg").data(using: .utf8)!)
        let json = promise.webhookJson(statusCode: 404, secretGetter: { nil })
        XCTAssertThrowsError(try hang(json)) { error in
            if case WebhookError.unacceptableStatusCode(404) = error {
                // pass
            } else {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testUnencryptedStatus504() {
        let promise = Promise<Data>.value(String("abcdefg").data(using: .utf8)!)
        let json = promise.webhookJson(statusCode: 504, secretGetter: { nil })
        XCTAssertThrowsError(try hang(json)) { error in
            if case WebhookError.unacceptableStatusCode(504) = error {
                // pass
            } else {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testUnencryptedStatus410() {
        let promise = Promise<Data>.value(String("abcdefg").data(using: .utf8)!)
        let json = promise.webhookJson(statusCode: 410, secretGetter: { nil })
        XCTAssertThrowsError(try hang(json)) { error in
            if case WebhookError.unacceptableStatusCode(410) = error {
                // pass
            } else {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testUnencryptedDictionary() throws {
        let dictionary = ["key": "value"]
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        let promise = Promise<Data>.value(data)
        let json = promise.webhookJson(statusCode: 200, secretGetter: { nil })

        XCTAssertEqual(try hang(json) as? [String: String], dictionary)
    }

    func testUnencryptedArray() throws {
        let array = ["one", "two"]
        let data = try JSONSerialization.data(withJSONObject: array, options: [])
        let promise = Promise<Data>.value(data)
        let json = promise.webhookJson(statusCode: 200, secretGetter: { nil })

        XCTAssertEqual(try hang(json) as? [String], array)
    }

    func testUnencryptedString() throws {
        let string = "value"
        let data = try JSONSerialization.data(withJSONObject: string, options: [.fragmentsAllowed])
        let promise = Promise<Data>.value(data)
        let json = promise.webhookJson(statusCode: 200, secretGetter: { nil })

        XCTAssertEqual(try hang(json) as? String, string)
    }

    func testEncryptedEmptyData() throws {
        let response = try Self.encryptedResponse(data: Data())
        let promise = Promise<Data>.value(response)
        let json = promise.webhookJson(secretGetter: { Self.secret })
        XCTAssertNotNil(try hang(json))
    }

    func testEncryptedDictionary() throws {
        let dictionary = ["key": "value"]
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        let promise = Promise<Data>.value(try Self.encryptedResponse(data: data))
        let json = promise.webhookJson(statusCode: 200, secretGetter: { Self.secret })

        XCTAssertEqual(try hang(json) as? [String: String], dictionary)
    }

    func testEncryptedArray() throws {
        let array = ["one", "two"]
        let data = try JSONSerialization.data(withJSONObject: array, options: [])
        let promise = Promise<Data>.value(try Self.encryptedResponse(data: data))
        let json = promise.webhookJson(statusCode: 200, secretGetter: { Self.secret })

        XCTAssertEqual(try hang(json) as? [String], array)
    }

    func testEncryptedString() throws {
        let string = "value"
        let data = try JSONSerialization.data(withJSONObject: string, options: [.fragmentsAllowed])
        let promise = Promise<Data>.value(try Self.encryptedResponse(data: data))
        let json = promise.webhookJson(statusCode: 200, secretGetter: { Self.secret })

        XCTAssertEqual(try hang(json) as? String, string)
    }

    func testEncryptedNoSecret() throws {
        let object = ["test": true]
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        let promise = Promise<Data>.value(try Self.encryptedResponse(data: data))
        let json = promise.webhookJson(statusCode: 200, secretGetter: { nil })

        XCTAssertThrowsError(try hang(json)) { error in
            XCTAssertEqual(error as? WebhookJsonParseError, .missingKey)
        }
    }

    func testEncryptedBadBase64() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "encrypted": true,
            "encrypted_data": "moo======",
        ], options: [])
        let promise = Promise<Data>.value(data)
        let json = promise.webhookJson(statusCode: 200, secretGetter: { [0, 1, 2, 3, 4] })

        XCTAssertThrowsError(try hang(json)) { error in
            XCTAssertEqual(error as? WebhookJsonParseError, .base64)
        }
    }

    func testEncryptedBadKey() throws {
        let data = try JSONSerialization.data(withJSONObject: ["test": true], options: [])
        let promise = Promise<Data>.value(try Self.encryptedResponse(data: data))
        let json = promise.webhookJson(statusCode: 200, secretGetter: { [0, 1, 2, 3, 4] })

        XCTAssertThrowsError(try hang(json)) { error in
            XCTAssertEqual(error as? WebhookJsonParseError, .decrypt)
        }
    }
}
