import Foundation
import HAKit
import Shared

/// Why a CarPlay action did not complete, in the terms the car can show the driver.
///
/// CarPlay is a glance-and-tap surface: the driver gets one short line, never a transport error.
/// The underlying failure is logged instead.
enum CarPlayOperationError: Error {
    /// There was no usable connection to the server when the action gave up.
    case noConnection
    /// The request reached HAKit but nothing came back before the deadline, while the connection
    /// still looked healthy.
    case timedOut
    /// The server, or the transport, reported a failure.
    case failed(Error)
    /// The action's server is no longer configured in the app — a Quick Access item outliving the
    /// server it points at, for instance. Shown as a plain failure: there is nothing about the
    /// drive or the connection for the driver to act on.
    case missingServer(id: String)
    /// The entity the action would act on isn't in the state cache, so the action was never
    /// attempted. Shown as a plain failure — nothing was sent, so this is not a timeout.
    case unresolvedEntity(id: String)

    /// Longest first, which is the order `CPAlertTemplate` expects: CarPlay renders the longest
    /// variant the vehicle's display can fit.
    var alertTitleVariants: [String] {
        switch self {
        case .noConnection:
            return [
                L10n.CarPlay.Operation.Error.NoConnection.title,
                L10n.CarPlay.Operation.Error.NoConnection.short,
            ]
        case .timedOut:
            return [
                L10n.CarPlay.Operation.Error.TimedOut.title,
                L10n.CarPlay.Operation.Error.TimedOut.short,
            ]
        case .failed, .missingServer, .unresolvedEntity:
            return [
                L10n.CarPlay.Operation.Error.Failed.title,
                L10n.CarPlay.Operation.Error.Failed.short,
            ]
        }
    }

    /// What went wrong, for the log only.
    var logDescription: String {
        switch self {
        case .noConnection:
            return "no connection to the server"
        case .timedOut:
            return "no response before the deadline"
        case let .failed(error):
            return error.localizedDescription
        case let .missingServer(id):
            return "no server configured with id \(id)"
        case let .unresolvedEntity(id):
            return "no cached state for entity \(id)"
        }
    }

    /// What to tell the driver about a failed action on `server`.
    ///
    /// A connection that isn't up explains the failure better than the transport error does, and is
    /// the thing the driver can act on — so the connection state at the moment of failure picks the
    /// message, whether the action reported an error or simply never answered.
    static func resolve(underlying: Error?, server: Server) -> CarPlayOperationError {
        resolve(underlying: underlying, isConnected: isConnected(to: server))
    }

    /// The decision itself, split from reading the live connection so it can be exercised for a
    /// connection state a unit test can't stand up.
    static func resolve(underlying: Error?, isConnected: Bool) -> CarPlayOperationError {
        guard isConnected else { return .noConnection }
        guard let underlying else { return .timedOut }
        return .failed(underlying)
    }

    private static func isConnected(to server: Server) -> Bool {
        guard let state = Current.api(for: server)?.connection.state else { return false }
        if case .ready = state {
            return true
        }
        return false
    }
}
