import Foundation

/// Where the watch keeps its own `mobile_app` registrations, one per server.
public protocol WatchDeviceRegistrationStore: AnyObject {
    func registration(for server: Identifier<Server>) -> WatchDeviceRegistration?
    /// `nil` forgets the registration, e.g. after the server reported it gone. Throws when the
    /// write didn't happen: a registration that isn't persisted must not be treated as done, or the
    /// next run registers the watch a second time and Home Assistant ends up with two devices.
    func set(_ registration: WatchDeviceRegistration?, for server: Identifier<Server>) throws
}
