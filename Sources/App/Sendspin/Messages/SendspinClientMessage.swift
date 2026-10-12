import Foundation

/// A JSON message this device sends once the encrypted channel is up.
enum SendspinClientMessage: Equatable {
    case hello(SendspinClientHello)
    case time(SendspinClientTime)
    case state(SendspinClientState)
    case command(SendspinClientCommand)
    case goodbye(SendspinClientGoodbye)
    case pairInit(SendspinPairInit)
    case pairFinalize(SendspinPairFinalize)
    case pairAbort(SendspinPairAbort)
    case handshake(SendspinNoiseHandshakeMessage)

    var type: String {
        switch self {
        case .hello: return "client/hello"
        case .time: return "client/time"
        case .state: return "client/state"
        case .command: return "client/command"
        case .goodbye: return "client/goodbye"
        case .pairInit: return "client/pair-init"
        case .pairFinalize: return "client/pair-finalize"
        case .pairAbort: return "pair/abort"
        case .handshake: return "noise/handshake"
        }
    }

    func encoded() throws -> Data {
        switch self {
        case let .hello(payload): return try encode(payload)
        case let .time(payload): return try encode(payload)
        case let .state(payload): return try encode(payload)
        case let .command(payload): return try encode(payload)
        case let .goodbye(payload): return try encode(payload)
        case let .pairInit(payload): return try encode(payload)
        case let .pairFinalize(payload): return try encode(payload)
        case let .pairAbort(payload): return try encode(payload)
        case let .handshake(payload): return try encode(payload)
        }
    }

    /// Also how the cleartext `client/init` is produced, whose exact bytes the handshake prologue
    /// hashes.
    static func encode(type: String, payload: some Codable) throws -> Data {
        let encoder = JSONEncoder()
        // Stable output keeps the bytes reproducible, which matters for `client/init`.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(SendspinEnvelope(type: type, payload: payload))
    }

    private func encode(_ payload: some Codable) throws -> Data {
        try Self.encode(type: type, payload: payload)
    }
}
