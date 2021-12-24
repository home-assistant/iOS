import APNS
import APNSwift
import Foundation
import SharedPush
import Vapor

class PushController {
    var appIdPrefix: String
    var jsonEncoder: JSONEncoder = .init()

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

    private func pushRequest(input: PushSendInput) throws -> PushRequest {
        precondition(input.encrypted && input.encryptedData != nil)

        let notification = PushSendEncryptedNotification(
            webhookId: input.registrationInfo.webhookId,
            encrypted: input.encrypted,
            encryptedData: input.encryptedData!
        )

        let encoded = try jsonEncoder.encode(notification)

        return .init(payload: encoded, collapseIdentifier: nil, pushType: .alert)
    }

    private func pushRequest(
        input: PushSendInput,
        parser: LegacyNotificationParser,
        body: ByteBuffer
    ) throws -> PushRequest {
        let json = try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] ?? [:]
        var parsed = parser.result(from: json, defaultRegistrationInfo: [:])

        let pushType: APNSwiftConnection.PushType
        let collapseId: String?

        switch parsed.headers["apns-push-type"] as? String {
        case "alert": pushType = .alert
        case "background": pushType = .background
        default: pushType = .alert
        }

        switch parsed.headers["apns-collapse-id"] as? String {
        case let .some(given): collapseId = given
        case .none: collapseId = nil
        }

        parsed.payload["webhook_id"] = input.registrationInfo.webhookId

        let contents = try JSONSerialization.data(withJSONObject: parsed.payload, options: [.withoutEscapingSlashes])

        return .init(
            payload: contents,
            collapseIdentifier: collapseId,
            pushType: pushType
        )
    }

    func send(req: Request) throws -> EventLoopFuture<PushSendOutput> {
        let input = try req.content.decode(PushSendInput.self)
        req.logger.debug("received: \(input)")

        guard input.registrationInfo.appId.starts(with: appIdPrefix) else {
            throw Abort(.notAcceptable, reason: "Invalid app ID '\(input.registrationInfo.appId)'")
        }

        let apns: PushRequest

        do {
            if input.encrypted {
                apns = try pushRequest(input: input)
            } else {
                apns = try pushRequest(
                    input: input,
                    parser: req.application.legacyNotificationParser,
                    body: req.body.data ?? ByteBuffer()
                )
            }
        } catch {
            throw Abort(.badRequest, reason: "Failed to parse request: \(String(describing: error))")
        }

        func send() -> EventLoopFuture<PushSendOutput> {
            req.apns.send(
                raw: apns.payload,
                pushType: apns.pushType,
                to: input.pushToken,
                expiration: nil,
                priority: nil,
                collapseIdentifier: apns.collapseIdentifier,
                topic: input.registrationInfo.appId,
                logger: req.logger,
                apnsID: nil
            ).map {
                let sentString = String(decoding: apns.payload, as: UTF8.self)
                req.logger.debug("sent: \(sentString)")
                return PushSendOutput(
                    sentPayload: sentString,
                    pushType: apns.pushType.rawValue,
                    collapseIdentifier: apns.collapseIdentifier
                )
            }
        }

        return send().flatMapError { error in
            if error is NoResponseWithinTimeoutError {
                return req.application.apns.pool.withConnection(
                    logger: req.logger,
                    on: req.eventLoop
                ) { conn in
                    req.logger.warning("got timeout error, closing connection and retrying")
                    return conn.close()
                }.flatMap {
                    send()
                }
            } else {
                return req.eventLoop.makeFailedFuture(Abort(
                    .unprocessableEntity,
                    reason: "Failed to send to APNS: \(String(describing: error))"
                ))
            }
        }
    }
}
