import Foundation
import ObjectMapper

public enum WebhookRequestContext: MapContext, Equatable {
    case server(Server)
    case local
}

public struct WebhookRequest: ImmutableMappable {
    public let type: String
    public let data: Any
    public let localMetadata: [String: Any]?

    public init(type: String, data: Any, localMetadata: [String: Any]? = nil) {
        self.type = type
        self.data = data
        self.localMetadata = localMetadata
    }

    public init(map: Map) throws {
        self.type = try map.value("type")
        self.data = try map.value("data")
        self.localMetadata = try? map.value("local_metadata")
    }

    enum ConversionError: Error {
        case dictionary
    }

    func asDictionary() throws -> [String: Any] {
        if let data = data as? [String: Any] {
            return data
        } else {
            throw ConversionError.dictionary
        }
    }

    public func mapping(map: Map) {
        guard let context = map.context as? WebhookRequestContext else {
            fatalError("context must be provided to avoid accidental unencrypted traffic")
        }

        type >>> map["type"]

        if context == .local {
            localMetadata >>> map["local_metadata"]
        }

        if case let .server(server) = context, let encrypted = encryptedData(server: server) {
            true >>> map["encrypted"]
            encrypted >>> map["encrypted_data"]
        } else {
            data >>> map["data"]
        }
    }

    private func encryptedData(server: Server) -> String? {
        guard let secret = server.info.connection.webhookSecretBytes(version: server.info.version) else {
            return nil
        }

        do {
            return try WebhookPayloadCrypto.encrypt(data, secret: secret)
        } catch {
            Current.Log.error("Unable to generate encrypted webhook payload: \(error)")
            return nil
        }
    }
}
