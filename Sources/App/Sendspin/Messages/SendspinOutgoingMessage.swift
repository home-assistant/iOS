import Foundation

/// Every message this client sends. Encoding returns the exact bytes that go on the wire, which
/// matters for `client/init`: those bytes are also the first half of the Noise prologue.
enum SendspinOutgoingMessage {
    case clientInit(clientId: String, suite: String)
    case noiseHandshake(Data)
    case clientHello(SendspinClientHello)
    case clientTime(clientTransmitted: Int64)
    case clientState(available: Bool, player: SendspinPlayerState?)
    case clientCommand(controller: SendspinControllerCommand)
    case clientGoodbye(SendspinGoodbyeReason)
    case pairFinalize(longTermPsk: String)
    case pairAbort(reason: String)

    private struct Envelope<Payload: Encodable>: Encodable {
        let type: String
        let payload: Payload
    }

    private struct InitPayload: Encodable {
        let clientId: String
        let version: Int
        let suite: String

        enum CodingKeys: String, CodingKey {
            case clientId = "client_id"
            case version
            case suite
        }
    }

    private struct HandshakePayload: Encodable {
        let data: String
    }

    private struct TimePayload: Encodable {
        let clientTransmitted: Int64

        enum CodingKeys: String, CodingKey {
            case clientTransmitted = "client_transmitted"
        }
    }

    private struct StatePayload: Encodable {
        let available: Bool
        let player: SendspinPlayerState?
    }

    private struct CommandPayload: Encodable {
        let controller: SendspinControllerCommand
    }

    private struct GoodbyePayload: Encodable {
        let reason: SendspinGoodbyeReason
    }

    private struct PairFinalizePayload: Encodable {
        let longTermPsk: String

        enum CodingKeys: String, CodingKey {
            case longTermPsk = "long_term_psk"
        }
    }

    private struct AbortPayload: Encodable {
        let reason: String
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        switch self {
        case let .clientInit(clientId, suite):
            let payload = InitPayload(clientId: clientId, version: 1, suite: suite)
            return try encoder.encode(Envelope(type: "client/init", payload: payload))
        case let .noiseHandshake(data):
            let payload = HandshakePayload(data: SendspinBase64URL.encode(data))
            return try encoder.encode(Envelope(type: "noise/handshake", payload: payload))
        case let .clientHello(hello):
            return try encoder.encode(Envelope(type: "client/hello", payload: hello))
        case let .clientTime(clientTransmitted):
            let payload = TimePayload(clientTransmitted: clientTransmitted)
            return try encoder.encode(Envelope(type: "client/time", payload: payload))
        case let .clientState(available, player):
            let payload = StatePayload(available: available, player: player)
            return try encoder.encode(Envelope(type: "client/state", payload: payload))
        case let .clientCommand(controller):
            let payload = CommandPayload(controller: controller)
            return try encoder.encode(Envelope(type: "client/command", payload: payload))
        case let .clientGoodbye(reason):
            let payload = GoodbyePayload(reason: reason)
            return try encoder.encode(Envelope(type: "client/goodbye", payload: payload))
        case let .pairFinalize(longTermPsk):
            let payload = PairFinalizePayload(longTermPsk: longTermPsk)
            return try encoder.encode(Envelope(type: "client/pair-finalize", payload: payload))
        case let .pairAbort(reason):
            return try encoder.encode(Envelope(type: "pair/abort", payload: AbortPayload(reason: reason)))
        }
    }
}
