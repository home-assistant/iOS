import Foundation

/// What a server knows this installation as, kept per server in the app group.
public struct RegistrationRecord: Codable, Equatable {
    public var current: RegistrationIdentity?
    /// Kept across attempts: the server may have made the registration before the response was lost.
    public var pending: RegistrationIdentity?

    public init(current: RegistrationIdentity? = nil, pending: RegistrationIdentity? = nil) {
        self.current = current
        self.pending = pending
    }
}
