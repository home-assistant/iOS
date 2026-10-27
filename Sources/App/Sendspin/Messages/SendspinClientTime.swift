import Foundation

/// `client/time`: this device's clock, in microseconds, for the server to echo back.
struct SendspinClientTime: Codable, Equatable {
    let clientTransmitted: Int64

    enum CodingKeys: String, CodingKey {
        case clientTransmitted = "client_transmitted"
    }
}
