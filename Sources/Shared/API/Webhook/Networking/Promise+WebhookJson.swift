import Foundation
import PromiseKit
import Sodium

enum WebhookJsonParseError: Error, Equatable {
    case empty
    case base64
    case missingKey
    case decrypt
}

extension Promise where T == Data? {
    func webhookJson(
        on queue: DispatchQueue? = nil,
        server: Server,
        statusCode: Int? = nil,
        requestURL: URL?,
        sodium: Sodium = Sodium(),
        secretGetter: @escaping () -> [UInt8]?,
        options: JSONSerialization.ReadingOptions = [.allowFragments]
    ) -> Promise<Any> {
        then { optionalData -> Promise<Any> in
            if let data = optionalData {
                return Promise<Data>.value(data).definitelyWebhookJson(
                    on: queue,
                    server: server,
                    statusCode: statusCode,
                    requestURL: requestURL,
                    sodium: sodium,
                    secretGetter: secretGetter,
                    options: options
                )
            } else {
                throw WebhookJsonParseError.empty
            }
        }
    }
}

extension Promise where T == Data {
    func webhookJson(
        on queue: DispatchQueue? = nil,
        server: Server,
        statusCode: Int? = nil,
        requestURL: URL?,
        sodium: Sodium = Sodium(),
        secretGetter: @escaping () -> [UInt8]?,
        options: JSONSerialization.ReadingOptions = [.allowFragments]
    ) -> Promise<Any> {
        definitelyWebhookJson(
            on: queue,
            server: server,
            statusCode: statusCode,
            requestURL: requestURL,
            sodium: sodium,
            secretGetter: secretGetter,
            options: options
        )
    }

    // Exists so that the Data? -> Data one doesn't accidentally refer to itself
    fileprivate func definitelyWebhookJson(
        on queue: DispatchQueue?,
        server: Server,
        statusCode: Int?,
        requestURL: URL?,
        sodium: Sodium,
        secretGetter: @escaping () -> [UInt8]?,
        options: JSONSerialization.ReadingOptions = [.allowFragments]
    ) -> Promise<Any> {
        if let statusCode {
            switch statusCode {
            case 204, 205:
                return .value(())
            case 400...:
                // some other error occurred that we don't want to parse as success
                let text: String = {
                    let message = "Webhook failed, server %@, with status code %@ - URL: %@"
                    if let requestURL {
                        return String(
                            format: message,
                            server.info.name,
                            String(statusCode),
                            URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.host ?? "Unknown"
                        )
                    } else {
                        return String(
                            format: message,
                            server.info.name,
                            String(statusCode),
                            "Unknown URL"
                        )
                    }
                }()
                Current.clientEventStore.addEvent(ClientEvent(
                    text: text,
                    type: .networkRequest,
                    payload: nil
                )).cauterize()
                return .init(error: WebhookError.unacceptableStatusCode(statusCode))
            default:
                break
            }
        }

        return map(on: queue) { data -> Any in
            if data.isEmpty {
                return ()
            } else {
                return try JSONSerialization.jsonObject(with: data, options: options)
            }
        }.map { object in
            guard let dictionary = object as? [String: Any],
                  let encoded = dictionary["encrypted_data"] as? String else {
                return object
            }

            guard let secret = secretGetter() else {
                throw WebhookJsonParseError.missingKey
            }

            guard let decoded = sodium.utils.base642bin(encoded, variant: .ORIGINAL, ignore: nil) else {
                throw WebhookJsonParseError.base64
            }

            guard let decrypted = sodium.secretBox.open(
                nonceAndAuthenticatedCipherText: decoded,
                secretKey: .init(secret)
            ) else {
                throw WebhookJsonParseError.decrypt
            }

            if decrypted.isEmpty {
                return ()
            } else {
                return try JSONSerialization.jsonObject(with: Data(decrypted), options: options)
            }
        }
    }
}
