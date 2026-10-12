import Foundation

/// A JSON message the server sends once the encrypted channel is up.
enum SendspinServerMessage: Equatable {
    case hello(SendspinServerHello)
    case activate(SendspinServerActivate)
    case time(SendspinServerTime)
    case state(SendspinServerState)
    case command(SendspinServerCommand)
    case streamStart(SendspinStreamStart)
    case streamClear(SendspinStreamRoles)
    case streamEnd(SendspinStreamRoles)
    case groupUpdate(SendspinGroupUpdate)
    case unpair
    case pairFinalize
    case pairAbort(SendspinPairAbort)
    /// A re-handshake: its Noise messages travel inside the encrypted channel.
    case handshake(SendspinNoiseHandshakeMessage)

    /// Returns `nil` for a well-formed message of a type this player does not implement, which the
    /// specification says to ignore; throws for anything that is not a valid message at all.
    static func decode(_ data: Data) throws -> SendspinServerMessage? {
        let decoder = JSONDecoder()
        let type = try decoder.decode(SendspinMessageHeader.self, from: data).type
        func payload<Payload: Codable>(_: Payload.Type) throws -> Payload {
            try decoder.decode(SendspinEnvelope<Payload>.self, from: data).payload
        }

        switch type {
        case "server/hello": return try .hello(payload(SendspinServerHello.self))
        case "server/activate": return try .activate(payload(SendspinServerActivate.self))
        case "server/time": return try .time(payload(SendspinServerTime.self))
        case "server/state": return try .state(payload(SendspinServerState.self))
        case "server/command": return try .command(payload(SendspinServerCommand.self))
        case "stream/start": return try .streamStart(payload(SendspinStreamStart.self))
        case "stream/clear": return try .streamClear(payload(SendspinStreamRoles.self))
        case "stream/end": return try .streamEnd(payload(SendspinStreamRoles.self))
        case "group/update": return try .groupUpdate(payload(SendspinGroupUpdate.self))
        case "server/unpair": return .unpair
        case "server/pair-finalize": return .pairFinalize
        case "pair/abort": return try .pairAbort(payload(SendspinPairAbort.self))
        case "noise/handshake": return try .handshake(payload(SendspinNoiseHandshakeMessage.self))
        default: return nil
        }
    }
}
