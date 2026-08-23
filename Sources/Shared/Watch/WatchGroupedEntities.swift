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
        public let entries: [WatchEntityEntry]

        public var id: String { deviceId }

        public init(deviceId: String, name: String, entries: [WatchEntityEntry]) {
            self.deviceId = deviceId
            self.name = name
            self.entries = entries
        }
    }

    /// Entities that stand on their own: no device, or the only one their device contributes here.
    public let ungrouped: [WatchEntityEntry]
    /// Devices contributing more than one entity, in display-name order.
    public let deviceGroups: [DeviceGroup]

    public var isEmpty: Bool { ungrouped.isEmpty && deviceGroups.isEmpty }

    /// Every entry, grouping undone — for screens that are already scoped to a single device, where
    /// re-stating that device as a section header would say nothing. Loose rows come first, then
    /// each group's rows; on a single-device screen that is exactly the original order.
    public var allEntries: [WatchEntityEntry] { ungrouped + deviceGroups.flatMap(\.entries) }

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
        var namePerDevice: [String: String] = [:]
        var entriesPerDevice: [String: [WatchEntityEntry]] = [:]
        for entry in entries {
            guard let device = entry.device, entryCountPerDevice[device.id, default: 0] > 1 else {
                ungrouped.append(entry)
                continue
            }
            namePerDevice[device.id] = device.name
            entriesPerDevice[device.id, default: []].append(entry)
        }

        return .init(
            ungrouped: ungrouped,
            // Dictionary order is arbitrary, so the id breaks name ties: without it two devices
            // sharing a name could swap places between two builds of the same data.
            deviceGroups: entriesPerDevice
                .map { deviceId, entries in
                    DeviceGroup(deviceId: deviceId, name: namePerDevice[deviceId] ?? deviceId, entries: entries)
                }
                .sorted { lhs, rhs in
                    let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                    if comparison != .orderedSame { return comparison == .orderedAscending }
                    return lhs.deviceId < rhs.deviceId
                }
        )
    }
}
