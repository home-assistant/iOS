import Foundation

/// How this device answers a `server/activate`.
enum SendspinActivationDecision: Equatable {
    case accept
    /// Not admissible: say why and close.
    case goodbye(SendspinGoodbyeReason)
    /// A pairing method this session cannot run: refuse the attempt, keep the connection.
    case pairAbortMethodNotSupported
}
