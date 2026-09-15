import Foundation

/// A device as the device registry describes it. Entities inherit their area from their device, and
/// the area view groups whatever is left over by the device it belongs to — those two are the only
/// reasons the home dashboard needs devices at all.
public struct HomeDevice: Identifiable, Equatable, Hashable, Sendable {
    /// `device_id`.
    public let id: String
    /// The name the integration gave the device.
    public let name: String?
    /// The name the user gave it, which wins when set.
    public let nameByUser: String?
    public let areaId: String?
    /// A child device without an area of its own inherits its parent's. Core nests a single level,
    /// so resolving it is a lookup rather than a walk.
    public let parentDeviceId: String?

    public init(
        id: String,
        name: String? = nil,
        nameByUser: String? = nil,
        areaId: String? = nil,
        parentDeviceId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.nameByUser = nameByUser
        self.areaId = areaId
        self.parentDeviceId = parentDeviceId
    }

    /// What to call the device on screen, the port of the frontend's `computeDeviceName`.
    public var displayName: String? {
        let candidate = nameByUser ?? name
        guard let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return candidate
    }
}
