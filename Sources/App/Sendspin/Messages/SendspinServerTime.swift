import Foundation

/// `server/time`: the three timestamps that, with the local receive time, make one sample for the
/// clock filter.
struct SendspinServerTime: Codable, Equatable {
    let clientTransmitted: Int64
    let serverReceived: Int64
    let serverTransmitted: Int64

    enum CodingKeys: String, CodingKey {
        case clientTransmitted = "client_transmitted"
        case serverReceived = "server_received"
        case serverTransmitted = "server_transmitted"
    }
}
