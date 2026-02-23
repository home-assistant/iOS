import Foundation

enum FrontEndConnectionState: String {
    case connected
    case disconnected
    case authInvalid = "auth-invalid"
    case unknown
}
