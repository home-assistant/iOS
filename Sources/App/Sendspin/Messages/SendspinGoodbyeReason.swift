import Foundation

/// Why the client is closing the connection. The server uses this to decide whether to reconnect.
enum SendspinGoodbyeReason: String, Codable {
    case anotherServer = "another_server"
    case shutdown
    case restart
    case userRequest = "user_request"
    case unauthorized
    case pairingRequired = "pairing_required"
    case concurrentAttempt = "concurrent_attempt"
    case unpaired
}
