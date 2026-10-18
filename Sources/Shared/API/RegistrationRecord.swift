import Foundation

/// What this installation keeps about its `mobile_app` registration with a server.
public struct RegistrationRecord: Codable, Equatable {
    /// The identity the registration was made with. `nil` when this installation has no record of it, as with a
    /// registration made before identities were recorded: `SettingsStore.currentRegistrationIdentity(for:)` then
    /// works it out.
    public var current: RegistrationIdentity?
    /// The identity this device is registering itself with as a new device, until the server confirms it. Kept
    /// across attempts, so one whose response was lost after the server had made the registration is replaced by
    /// the next attempt rather than left behind as a device nothing reports to.
    public var pending: RegistrationIdentity?

    public init(current: RegistrationIdentity? = nil, pending: RegistrationIdentity? = nil) {
        self.current = current
        self.pending = pending
    }
}
