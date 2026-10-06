import Foundation

/// The devices an entity belongs to, named for its context line.
public struct EntityDeviceContext: Equatable, Sendable {
    public let deviceName: String?
    public let parentDeviceName: String?
    public let reach: EntityContextReach

    public init(deviceName: String?, parentDeviceName: String?, reach: EntityContextReach) {
        self.deviceName = deviceName
        self.parentDeviceName = parentDeviceName
        self.reach = reach
    }
}
