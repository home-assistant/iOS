import Foundation

/// A decoded `server/time`, carrying three of the four timestamps the clock filter needs. The
/// fourth — when this client received the response — is taken locally as the frame arrives.
struct SendspinTimeSample: Decodable, Equatable {
    let clientTransmitted: Int64
    let serverReceived: Int64
    let serverTransmitted: Int64

    enum CodingKeys: String, CodingKey {
        case clientTransmitted = "client_transmitted"
        case serverReceived = "server_received"
        case serverTransmitted = "server_transmitted"
    }
}
