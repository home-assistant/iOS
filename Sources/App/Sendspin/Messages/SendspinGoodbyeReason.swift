import Foundation

/// Why this device is closing a connection, sent in `client/goodbye`.
enum SendspinGoodbyeReason: String, Codable, Equatable {
    case anotherServer = "another_server"
    case shutdown
    case restart
    case userRequest = "user_request"
    case unauthorized
    case pairingRequired = "pairing_required"
    case concurrentAttempt = "concurrent_attempt"
    case unpaired
}
