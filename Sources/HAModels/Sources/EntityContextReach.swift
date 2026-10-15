import Foundation

/// How far up an entity's devices its context line reaches, following core's `next_name_part` links:
/// the walk stops at the first node with an area of its own, so a device is never named under an
/// area it isn't in. Servers that predate `next_name_part` get the same answer from the area and
/// parent ids it is computed from.
public enum EntityContextReach: Equatable, Sendable {
    case area
    case device
    case parentDevice

    public init(entityNextNamePart: String?, entityAreaId: String?, device: AppDeviceRegistry?) {
        let entityPart = entityNextNamePart ?? (entityAreaId == nil ? Self.devicePart : Self.areaPart)
        guard entityPart == Self.devicePart else {
            self = .area
            return
        }
        let devicePart = device?.nextNamePart
            ?? (device?.parentDeviceId != nil && device?.areaId == nil ? Self.parentDevicePart : nil)
        self = devicePart == Self.parentDevicePart ? .parentDevice : .device
    }

    private static let areaPart = "area"
    private static let devicePart = "device"
    private static let parentDevicePart = "parent_device"
}
