import Foundation

/// Where the watch keeps its own `mobile_app` registrations, one per server.
public protocol WatchDeviceRegistrationStore: AnyObject {
    func registration(for server: Identifier<Server>) -> WatchDeviceRegistration?
    /// `nil` forgets the registration, e.g. after the server reported it gone.
    func set(_ registration: WatchDeviceRegistration?, for server: Identifier<Server>)
}
