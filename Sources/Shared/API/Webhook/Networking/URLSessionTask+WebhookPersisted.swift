import Foundation
import ObjectMapper

struct WebhookPersisted: Codable {
    var server: Identifier<Server>
    var request: WebhookRequest
    var identifier: WebhookResponseIdentifier

    enum CodingKeys: CodingKey {
        case server
        case request
        case identifier
    }

    enum CodingError: Error {
        case requestFailure
    }

    init(server: Identifier<Server>, request: WebhookRequest, identifier: WebhookResponseIdentifier) {
        self.server = server
        self.request = request
        self.identifier = identifier
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(
            Mapper<WebhookRequest>(context: WebhookRequestContext.local).toJSON(request),
            forKey: .request
        )
        try container.encode(identifier, forKey: .identifier)
        try container.encode(server, forKey: .server)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let json = try container.decode([String: Any].self, forKey: .request)
        self.request = try Mapper<WebhookRequest>(context: WebhookRequestContext.local).map(JSON: json)
        self.identifier = try container.decode(WebhookResponseIdentifier.self, forKey: .identifier)
        self.server = try container.decode(Identifier<Server>.self, forKey: .server)
    }
}

extension URLSessionTask {
    var webhookPersisted: WebhookPersisted? {
        get {
            if let data = taskDescription.flatMap({ Data(base64Encoded: $0) }) {
                return try? JSONDecoder().decode(WebhookPersisted.self, from: data)
            } else {
                return nil
            }
        }
        set {
            taskDescription = try? JSONEncoder().encode(newValue).base64EncodedString()
        }
    }
}
