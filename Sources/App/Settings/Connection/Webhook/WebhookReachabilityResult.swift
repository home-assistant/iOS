import Foundation
import Shared

/// Outcome of a reachability check against a webhook URL.
enum WebhookReachabilityResult: Equatable {
    case reachable(statusCode: Int?)
    case unreachable(message: String)

    var isReachable: Bool {
        switch self {
        case .reachable:
            return true
        case .unreachable:
            return false
        }
    }

    var localizedDescription: String {
        switch self {
        case let .reachable(statusCode):
            if let statusCode {
                return L10n.Settings.ConnectionSection.Cloudhook.CheckReachability.reachableStatusCode(statusCode)
            } else {
                return L10n.Settings.ConnectionSection.Cloudhook.CheckReachability.reachable
            }
        case let .unreachable(message):
            return L10n.Settings.ConnectionSection.Cloudhook.CheckReachability.unreachable(message)
        }
    }
}
