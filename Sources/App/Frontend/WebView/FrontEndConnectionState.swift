import Foundation

enum FrontEndConnectionState: String {
    case connected
    case loaded
    case disconnected
    case authInvalid = "auth-invalid"
    case unknown
}

extension FrontEndConnectionState {
    var isReadyForDisplay: Bool {
        switch self {
        case .connected, .loaded:
            true
        case .disconnected, .authInvalid, .unknown:
            false
        }
    }
}
