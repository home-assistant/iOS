import APNS
import APNSwift
import Foundation
import SharedPush
import Vapor

class PushController {
    var appIdPrefix: String

    init(appIdPrefix: String) {
        self.appIdPrefix = appIdPrefix
    }

    private struct PushSendEncryptedNotification: APNSwiftNotification {
        enum CodingKeys: String, CodingKey {
            case aps = "aps"
            case webhookId = "webhook_id"
            case encrypted = "encrypted"
            case encryptedData = "encrypted_data"
        }

        var aps: APNSwiftPayload = .init(
            alert: .init(
                title: "Encrypted notification",
                body: "If you're seeing this message, decryption failed."
            ),
            sound: .normal("default"),
            hasMutableContent: true
        )
        var webhookId: String?
        var encrypted: Bool
        var encryptedData: String
    }

    private struct PushRequest {
        var payload: Data
        var collapseIdentifier: String?
        var pushType: APNSwiftConnection.PushType
    }

    private static func pushRequest(encryptedInput input: PushSendInput) throws -> PushRequest {
        precondition(input.encrypted && input.encryptedData != nil)

        let notification = PushSendEncryptedNotification(
            webhookId: input.registrationInfo.webhookId,
            encrypted: input.encrypted,
            encryptedData: input.encryptedData!
        )

        let encoded = try JSONEncoder().encode(notification)

        return .init(payload: encoded, collapseIdentifier: nil, pushType: .alert)
    }

    private static func pushRequest(
        input: PushSendInput,
        parser: LegacyNotificationParser,
        body: ByteBuffer
    ) throws -> PushRequest {
        let json = try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] ?? [:]
        let parsed = parser.result(from: json, defaultRegistrationInfo: [:])
        assert(parsed.payload["webhook_id"] as? String == input.registrationInfo.webhookId)

        let contents = try JSONSerialization.data(withJSONObject: parsed.payload, options: [])
        let collapseId = parsed.headers["apns-collapse-id"] as? String
        let pushType = parsed.headers["apns-push-type"] as? String

        return .init(
            payload: contents,
            collapseIdentifier: collapseId,
            pushType: pushType.flatMap { .init(rawValue: $0) } ?? .alert
        )
    }

    func send(req: Request) async throws -> Response {
        let input = try req.content.decode(PushSendInput.self)
        req.logger.debug("received: \(input)")

        guard input.registrationInfo.appId.starts(with: appIdPrefix) else {
            throw Abort(.notAcceptable, reason: "Invalid app ID '\(input.registrationInfo.appId)'")
        }

        if let startLimits = try? await req.application.rateLimits.rateLimit(for: input.pushToken),
           startLimits.exceedsMaximum {
            // if the redis call fails, we still permit the notification to be sent
            throw Abort(.tooManyRequests, reason: "Exceeded rate limit")
        }

        let apns: PushRequest

        if input.encrypted {
            apns = try Self.pushRequest(encryptedInput: input)
        } else {
            apns = try Self.pushRequest(
                input: input,
                parser: req.application.legacyNotificationParser,
                body: req.body.data ?? ByteBuffer()
            )
        }

        let messageId = UUID()
        req.logger[metadataKey: "apns-id"] = .stringConvertible(messageId)

        func send() async throws {
            try await req.apns.send(
                raw: apns.payload,
                pushType: apns.pushType,
                to: input.pushToken,
                expiration: nil,
                priority: nil,
                collapseIdentifier: apns.collapseIdentifier,
                topic: input.registrationInfo.appId,
                logger: req.logger,
                apnsID: messageId
            ).get()
        }

        do {
            try await send()
        } catch is NoResponseWithinTimeoutError {
            try await req.application.apns.pool.withConnection(
                logger: req.logger,
                on: req.eventLoop
            ) { conn -> EventLoopFuture<Void> in
                req.logger.warning("got timeout error, closing connection and retrying")
                return conn.close()
            }.get()

            try await send()
        } catch {
            _ = try? await req.application.rateLimits.increment(kind: .error, for: input.pushToken)

            throw Abort(
                .unprocessableEntity,
                reason: "Failed to send to APNS: \(String(describing: error))"
            )
        }

        let rateLimits = try await req.application.rateLimits.increment(kind: .successful, for: input.pushToken)
        let sentString = String(decoding: apns.payload, as: UTF8.self)
        req.logger.debug("sent: \(sentString)")
        let response = Response(status: .created)
        try response.content.encode(PushSendOutput(
            target: input.pushToken,
            messageId: messageId,
            pushType: apns.pushType.rawValue,
            collapseIdentifier: apns.collapseIdentifier,
            rateLimits: .init(
                rateLimits: rateLimits,
                resetsAt: await req.application.rateLimits.expirationDate(for: input.pushToken)
            ),
            sentPayload: sentString
        ))
        return response
    }
}
