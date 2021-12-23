import APNS
import APNSwift
import Foundation
import SharedPush
import Vapor

struct PushController {
    let appIdPrefix: String
    let jsonEncoder: JSONEncoder

    init(appIdPrefix: String) {
        self.appIdPrefix = appIdPrefix
        self.jsonEncoder = JSONEncoder()
    }

    private struct PushSendEncryptedNotification: APNSwiftNotification {
        var aps: APNSwiftPayload = .init(
            alert: .init(
                title: "Encrypted Notification",
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

    private func pushRequest(req: Request, input: PushSendInput) throws -> PushRequest {
        precondition(input.encrypted)

        guard let encryptedData = input.encryptedData else {
            throw Abort(.badRequest, reason: "Missing encrypted data")
        }

        let notification = PushSendEncryptedNotification(
            webhookId: input.registrationInfo.webhookId,
            encrypted: input.encrypted,
            encryptedData: encryptedData
        )

        let encoded = try jsonEncoder.encode(notification)

        return .init(payload: encoded, collapseIdentifier: nil, pushType: .alert)
    }

    private func pushRequest(
        req: Request,
        input: PushSendInput,
        headers: [String: Any],
        payload: [String: Any]
    ) throws -> PushRequest {
        let pushType: APNSwiftConnection.PushType
        let collapseId: String?

        switch headers["apns-push-type"] as? String {
        case "alert": pushType = .alert
        case "background": pushType = .background
        default: pushType = .alert
        }

        if let given = headers["apns-collapse-id"] as? String {
            collapseId = given
        } else {
            collapseId = nil
        }

        let contents = try JSONSerialization.data(withJSONObject: payload, options: [.withoutEscapingSlashes])

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
            throw Abort(.badRequest, reason: "Invalid app ID")
        }

        let apns: PushRequest

        do {
            if input.encrypted {
                apns = try pushRequest(req: req, input: input)
            } else {
                let json = try JSONSerialization
                    .jsonObject(with: req.body.data ?? ByteBuffer(), options: []) as? [String: Any] ?? [:]
                let result = NotificationParserLegacy.result(from: json, defaultRegistrationInfo: [:])
                apns = try pushRequest(req: req, input: input, headers: result.headers, payload: result.payload)
            }
        } catch {
            throw Abort(.badRequest, reason: "Failed to parse request: \(String(describing: error))")
        }

        return req.apns.send(
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
            return PushSendOutput(sentPayload: sentString)
        }.flatMapError { error in
            req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Failed to send to APNS: \(String(describing: error))"))
        }
    }
}
