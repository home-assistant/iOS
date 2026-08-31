import Foundation

/// One watch section's entities (the controls or the sensors of an area or a device) split into the
/// rows the screen renders directly and the per-device sections it renders below them.
///
/// A device only earns its own section when it contributes **more than one** entity to the section:
/// on a watch-sized screen a lone row under a device heading costs a line and tells the user nothing
/// the row itself doesn't already say. Entities without a device are never grouped.
public struct WatchGroupedEntities {
    /// The entities one device contributes to a section, rendered under a header titled with the
    /// device name that drills into the device's own screen.
    public struct DeviceGroup: Identifiable {
        public let deviceId: String
        public let name: String
        /// Name of the device this one is a part of, when it is a child device.
        public let parentName: String?
        public let entries: [WatchEntityEntry]

        public var id: String { deviceId }

        public init(deviceId: String, name: String, parentName: String? = nil, entries: [WatchEntityEntry]) {
            self.deviceId = deviceId
            self.name = name
            self.parentName = parentName
            self.entries = entries
        }
    }

    /// Entities that stand on their own: no device, or the only one their device contributes here.
    public let ungrouped: [WatchEntityEntry]
    /// Devices contributing more than one entity, in display-name order.
    public let deviceGroups: [DeviceGroup]

    public var isEmpty: Bool { ungrouped.isEmpty && deviceGroups.isEmpty }

    public static let empty = WatchGroupedEntities(ungrouped: [], deviceGroups: [])

    public init(ungrouped: [WatchEntityEntry], deviceGroups: [DeviceGroup]) {
        self.ungrouped = ungrouped
        self.deviceGroups = deviceGroups
    }

    /// Split already-ordered entries into loose rows and per-device sections.
    ///
    /// The caller's order is preserved both in `ungrouped` and inside each group — the entries
    /// arrive sorted the way the section wants to read (domain order for controls, alphabetical for
    /// sensors) and grouping must not reshuffle that. Groups themselves are ordered by device name
    /// rather than by first appearance, so the sections don't jump around when the entity ordering
    /// inside them changes.
    public static func make(_ entries: [WatchEntityEntry]) -> WatchGroupedEntities {
        var entryCountPerDevice: [String: Int] = [:]
        for entry in entries {
            guard let device = entry.device else { continue }
            entryCountPerDevice[device.id, default: 0] += 1
        }

        var ungrouped: [WatchEntityEntry] = []
        var devicePerId: [String: WatchEntityEntry.Device] = [:]
        var entriesPerDevice: [String: [WatchEntityEntry]] = [:]
        for entry in entries {
            guard let device = entry.device, entryCountPerDevice[device.id, default: 0] > 1 else {
                ungrouped.append(entry)
                continue
            }
            devicePerId[device.id] = device
            entriesPerDevice[device.id, default: []].append(entry)
        }

        return .init(
            ungrouped: ungrouped,
            // Dictionary order is arbitrary, so the id breaks name ties: without it two devices
            // sharing a name could swap places between two builds of the same data.
            deviceGroups: entriesPerDevice
                .map { deviceId, entries in
                    let device = devicePerId[deviceId]
                    return DeviceGroup(
                        deviceId: deviceId,
                        name: device?.name ?? deviceId,
                        parentName: device?.parentName,
                        entries: entries
                    )
                }
                // A child device's section follows its parent's rather than sorting on its own name.
                .sorted { lhs, rhs in
                    let comparison = (lhs.parentName ?? lhs.name)
                        .localizedCaseInsensitiveCompare(rhs.parentName ?? rhs.name)
                    if comparison != .orderedSame { return comparison == .orderedAscending }
                    if (lhs.parentName == nil) != (rhs.parentName == nil) { return lhs.parentName == nil }
                    let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                    if nameComparison != .orderedSame { return nameComparison == .orderedAscending }
                    return lhs.deviceId < rhs.deviceId
                }
        )
    }

    /// The same sections with one device's group folded back into the loose rows, leading them —
    /// for a screen already named after that device, where its child devices keep their sections.
    public func flatteningGroup(deviceId: String) -> WatchGroupedEntities {
        guard let index = deviceGroups.firstIndex(where: { $0.deviceId == deviceId }) else { return self }
        var groups = deviceGroups
        let group = groups.remove(at: index)
        return .init(ungrouped: group.entries + ungrouped, deviceGroups: groups)
    }
}
