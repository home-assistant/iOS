import APNS
@testable import App
import Foundation
import SharedPush
import XCTVapor

final class PushControllerTests: AbstractTestCase {
    private var parser: FakeLegacyNotificationParser!
    private var rateLimitsCache: FakeCache!

    override func setUpWithError() throws {
        try super.setUpWithError()
        parser = .init()
        rateLimitsCache = .init(eventLoop: app.eventLoopGroup.next())

        app.legacyNotificationParser.parser = parser
        app.rateLimits.cache = rateLimitsCache
    }

    func testMissingInformation() throws {
        let contents: [(HTTPResponseStatus, [String: Any])] = [
            (.badRequest, [:]),
            (.badRequest, ["push_token": "abc"]),
            (.badRequest, ["push_token": true, "registration_info": "string"]),
            (.badRequest, ["push_token": "abc", "registration_info": [String: String]()]),
            (.notAcceptable, ["push_token": "abc", "registration_info": [
                "app_id": "in_app_id",
                "app_version": "in_app_version",
                "os_version": "in_os_version",
                "webhook_id": "in_webhook_id",
            ]]),
        ]

        for (status, content) in contents {
            let body = try String(decoding: JSONSerialization.data(withJSONObject: content, options: []), as: UTF8.self)

            try app.test(.POST, "push/send", beforeRequest: { req in
                try req.content.encode(body, as: .plainText)
                req.headers.replaceOrAdd(name: .contentType, value: "application/json")
            }, afterResponse: { res in
                XCTAssertEqual(res.status, status)
            })
        }
    }

    func testEncryptedNotificationWithoutData() throws {
        try app.test(.POST, "push/send", beforeRequest: { req in
            try req.content.encode(PushSendInput(
                encrypted: true,
                encryptedData: nil,
                registrationInfo: .init(
                    appId: "io.robbie.HomeAssistant",
                    appVersion: "1.0",
                    osVersion: "10.0",
                    webhookId: "webhook_id"
                ),
                pushToken: "push_token"
            ))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .badRequest)
        })

        XCTAssertNil(rateLimitsCache.values[RateLimitsImpl.key(for: "push_token")])
    }

    func testEncryptedNotificationWithDataSucceeds() throws {
        Request.TestableAPNS.pendingSendHandler = { pending in
            let payloadJSON = (try? JSONSerialization.jsonObject(with: pending.payload) as? [String: Any]) ?? [:]

            XCTAssertEqual(payloadJSON["webhook_id"] as? String, "given_webhook_id")
            XCTAssertEqual(payloadJSON["encrypted"] as? Bool, true)
            XCTAssertEqual(payloadJSON["encrypted_data"] as? String, "given_encrypted_data")

            let aps = payloadJSON["aps"] as? [String: Any] ?? [:]
            let alert = aps["alert"] as? [String: Any] ?? [:]

            XCTAssertEqual(alert["title"] as? String, "Encrypted notification")
            XCTAssertEqual(alert["body"] as? String, "If you're seeing this message, decryption failed.")
            XCTAssertEqual(aps["mutable-content"] as? Int, 1)

            XCTAssertEqual(pending.pushType, .alert)
            XCTAssertEqual(pending.deviceToken, "given_push_token")
            XCTAssertNil(pending.expiration)
            XCTAssertNil(pending.priority)
            XCTAssertNil(pending.collapseIdentifier)
            XCTAssertEqual(pending.topic, "io.robbie.HomeAssistant.test_app_id")
            XCTAssertNotNil(pending.apnsID)

            pending.promise.completeWith(.success(()))
        }

        try app.test(.POST, "push/send", beforeRequest: { req in
            try req.content.encode(PushSendInput(
                encrypted: true,
                encryptedData: "given_encrypted_data",
                registrationInfo: .init(
                    appId: "io.robbie.HomeAssistant.test_app_id",
                    appVersion: "1.0",
                    osVersion: "10.0",
                    webhookId: "given_webhook_id"
                ),
                pushToken: "given_push_token"
            ))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .created)
        })

        let rateLimits = try XCTUnwrap(
            rateLimitsCache.values[RateLimitsImpl.key(for: "given_push_token")] as? RateLimitsValues
        )
        XCTAssertEqual(rateLimits.successful, 1)
        XCTAssertEqual(rateLimits.errors, 0)
    }

    func testEncryptedNotificationWithDataFails() throws {
        enum FailureError: Error {
            case failure
        }

        Request.TestableAPNS.pendingSendHandler = { pending in
            pending.promise.completeWith(.failure(FailureError.failure))
        }

        try app.test(.POST, "push/send", beforeRequest: { req in
            try req.content.encode(PushSendInput(
                encrypted: true,
                encryptedData: "given_encrypted_data",
                registrationInfo: .init(
                    appId: "io.robbie.HomeAssistant.test_app_id",
                    appVersion: "1.0",
                    osVersion: "10.0",
                    webhookId: "given_webhook_id"
                ),
                pushToken: "given_push_token"
            ))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .unprocessableEntity)
            XCTAssertContains(res.body.string, "Failed to send to APNS")
        })

        let rateLimits = try XCTUnwrap(
            rateLimitsCache.values[RateLimitsImpl.key(for: "given_push_token")] as? RateLimitsValues
        )
        XCTAssertEqual(rateLimits.successful, 0)
        XCTAssertEqual(rateLimits.errors, 1)
    }

    func testUnencrypted() throws {
        struct UnencryptedTestCase {
            var pushType: APNSwiftConnection.PushType
            var pushTypeRaw: String
            var webhookId: String?
            var collapseId: String?
        }

        var testCases = [UnencryptedTestCase]()

        for (pushType, rawPushType) in [
            (APNSwiftConnection.PushType.alert, "alert"),
            (APNSwiftConnection.PushType.background, "background"),
            (APNSwiftConnection.PushType.alert, "other"),
        ] {
            for webhookId in [nil, "given_webhook_id"] {
                for collapseId in [nil, "given_collapse_id"] {
                    testCases.append(.init(
                        pushType: pushType,
                        pushTypeRaw: rawPushType,
                        webhookId: webhookId,
                        collapseId: collapseId
                    ))
                }
            }
        }

        for testCase in testCases {
            let pushToken = UUID().uuidString
            let rawInput: [String: Any] = [
                "message": "message",
                "push_token": pushToken,
                "registration_info": [
                    "app_id": "io.robbie.HomeAssistant.unit-test",
                    "app_version": "1.0",
                    "os_version": "10.0",
                    "webhook_id": testCase.webhookId,
                ],
            ]
            let body = try String(
                decoding: JSONSerialization.data(withJSONObject: rawInput, options: []),
                as: UTF8.self
            )

            parser.resultHandler = { input in
                XCTAssertEqual(
                    try? XCTUnwrap(JSONSerialization.data(withJSONObject: rawInput, options: [.sortedKeys])),
                    try? XCTUnwrap(JSONSerialization.data(withJSONObject: input, options: [.sortedKeys]))
                )

                return .init(headers: [
                    "apns-push-type": testCase.pushTypeRaw,
                    "apns-collapse-id": testCase.collapseId as Any,
                ], payload: [
                    "aps": [
                        "alert": [
                            "title": "Title",
                            "body": "Body",
                        ],
                    ],
                    "homeassistant": [
                        "test": true,
                    ],
                    "webhook_id": testCase.webhookId as Any,
                ])
            }

            Request.TestableAPNS.pendingSendHandler = { pending in
                let payloadJSON = (try? JSONSerialization.jsonObject(with: pending.payload) as? [String: Any]) ?? [:]

                XCTAssertEqual(payloadJSON["webhook_id"] as? String, testCase.webhookId)
                XCTAssertNil(payloadJSON["encrypted"])
                XCTAssertNil(payloadJSON["encrypted_data"])

                let aps = payloadJSON["aps"] as? [String: Any] ?? [:]
                let alert = aps["alert"] as? [String: Any] ?? [:]

                XCTAssertEqual(alert["title"] as? String, "Title")
                XCTAssertEqual(alert["body"] as? String, "Body")
                XCTAssertNil(aps["mutable-content"])

                XCTAssertEqual(pending.pushType, testCase.pushType)
                XCTAssertEqual(pending.deviceToken, pushToken)
                XCTAssertNil(pending.expiration)
                XCTAssertNil(pending.priority)
                XCTAssertEqual(pending.collapseIdentifier, testCase.collapseId)
                XCTAssertEqual(pending.topic, "io.robbie.HomeAssistant.unit-test")
                XCTAssertNotNil(pending.apnsID)

                pending.promise.completeWith(.success(()))
            }

            try app.test(.POST, "push/send", beforeRequest: { req in
                try req.content.encode(body, as: .plainText)
                req.headers.replaceOrAdd(name: .contentType, value: "application/json")
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .created)
            })

            let rateLimits = try XCTUnwrap(
                rateLimitsCache.values[RateLimitsImpl.key(for: pushToken)] as? RateLimitsValues
            )
            XCTAssertEqual(rateLimits.successful, 1)
            XCTAssertEqual(rateLimits.errors, 0)
        }
    }

    func testSendBeyondRateLimits() throws {
        rateLimitsCache.values[RateLimitsImpl.key(for: "given_push_token")] = RateLimitsValues(
            successful: RateLimitsValues.dailyMaximum,
            errors: 0
        )

        try app.test(.POST, "push/send", beforeRequest: { req in
            try req.content.encode(PushSendInput(
                encrypted: true,
                encryptedData: "given_encrypted_data",
                registrationInfo: .init(
                    appId: "io.robbie.HomeAssistant.test_app_id",
                    appVersion: "1.0",
                    osVersion: "10.0",
                    webhookId: "given_webhook_id"
                ),
                pushToken: "given_push_token"
            ))
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .tooManyRequests)
        })

        let rateLimits = try XCTUnwrap(
            rateLimitsCache.values[RateLimitsImpl.key(for: "given_push_token")] as? RateLimitsValues
        )
        XCTAssertEqual(rateLimits.successful, RateLimitsValues.dailyMaximum)
        XCTAssertEqual(rateLimits.errors, 0)
    }
}
