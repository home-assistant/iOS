import Foundation

/// Every server message this client understands, decoded from the JSON envelope shared by the
/// cleartext handshake frames and the encrypted frames that follow.
enum SendspinIncomingMessage {
    case serverInit(serverId: String, version: Int)
    case noiseHandshake(Data)
    case serverHello(name: String)
    case activate(SendspinActivation)
    case time(SendspinTimeSample)
    case serverState(SendspinServerState)
    case playerCommand(SendspinPlayerCommand)
    case streamStart(SendspinStreamStart)
    case streamClear(roles: [String]?)
    case streamEnd(roles: [String]?)
    case groupUpdate(SendspinGroupState)
    case unpair
    case pairFinalize
    case pairAbort(reason: String)
    /// A message from a newer revision of the specification. Ignored, but worth logging.
    case unrecognized(type: String)

    static func decode(_ data: Data) throws -> SendspinIncomingMessage {
        guard
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let type = object["type"] as? String
        else {
            throw SendspinProtocolError.malformedMessage
        }
        let payload = object["payload"] as? [String: Any] ?? [:]
        let decoder = JSONDecoder()

        switch type {
        case "server/init":
            guard let serverId = payload["server_id"] as? String, let version = payload["version"] as? Int else {
                throw SendspinProtocolError.malformedMessage
            }
            return .serverInit(serverId: serverId, version: version)
        case "noise/handshake":
            guard let encoded = payload["data"] as? String, let bytes = SendspinBase64URL.decode(encoded) else {
                throw SendspinProtocolError.malformedMessage
            }
            return .noiseHandshake(bytes)
        case "server/hello":
            guard let name = payload["name"] as? String else { throw SendspinProtocolError.malformedMessage }
            return .serverHello(name: name)
        case "server/activate":
            return .activate(try decode(SendspinActivation.self, from: payload, using: decoder))
        case "server/time":
            return .time(try decode(SendspinTimeSample.self, from: payload, using: decoder))
        case "server/state":
            return .serverState(try decode(SendspinServerState.self, from: payload, using: decoder))
        case "server/command":
            guard let player = payload["player"] as? [String: Any] else {
                // Only the player object is relevant here; a source command is not ours to run.
                return .unrecognized(type: type)
            }
            return .playerCommand(try decode(SendspinPlayerCommand.self, from: player, using: decoder))
        case "stream/start":
            return .streamStart(try decode(SendspinStreamStart.self, from: payload, using: decoder))
        case "stream/clear":
            return .streamClear(roles: payload["roles"] as? [String])
        case "stream/end":
            return .streamEnd(roles: payload["roles"] as? [String])
        case "group/update":
            return .groupUpdate(try decode(SendspinGroupState.self, from: payload, using: decoder))
        case "server/unpair":
            return .unpair
        case "server/pair-finalize":
            return .pairFinalize
        case "pair/abort":
            return .pairAbort(reason: payload["reason"] as? String ?? "")
        default:
            return .unrecognized(type: type)
        }
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        from payload: [String: Any],
        using decoder: JSONDecoder
    ) throws -> Value {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            throw SendspinProtocolError.malformedMessage
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SendspinProtocolError.malformedMessage
        }
    }
}
