import Foundation

/// The two sections the watch's area and device screens render — controllable entities first,
/// display-only sensors after — resolved from the locally-mirrored database.
///
/// Both screens build their content through here so an entity is filtered, named, ordered and
/// grouped by device identically wherever it shows up.
public struct WatchEntitySections {
    /// Controllable entities, most commonly used domain first.
    public let controls: WatchGroupedEntities
    /// Display-only sensors, alphabetical.
    public let sensors: WatchGroupedEntities

    public var isEmpty: Bool { controls.isEmpty && sensors.isEmpty }

    public static let empty = WatchEntitySections(controls: .empty, sensors: .empty)

    public init(controls: WatchGroupedEntities, sensors: WatchGroupedEntities) {
        self.controls = controls
        self.sensors = sensors
    }

    /// Resolve the server's watch-compatible entities that `isIncluded` accepts into both sections.
    ///
    /// The predicate receives the entity's device too, so a device screen can select by device
    /// without resolving the registry a second time.
    ///
    /// Synchronous database work throughout — `loadInformation`, the device map and every info
    /// lookup — so call it off the main thread. `completion` fires on whatever queue
    /// `loadInformation` calls back on.
    public static func make(
        serverId: String,
        isIncluded: @escaping (HAAppEntity, AppDeviceRegistry?) -> Bool,
        completion: @escaping (WatchEntitySections) -> Void
    ) {
        let provider = Current.magicItemProvider()
        provider.loadInformation { entitiesPerServer in
            let allowedDomains = Set(Domain.watchAddable.map(\.rawValue))
            let excluded = HAAppEntity.watchExcludedEntityIds(serverId: serverId)
            let serverEntities = entitiesPerServer[serverId] ?? []
            // One registry + device-registry read for the whole screen, rather than one per row.
            let (devices, devicesById) = serverEntities.deviceMaps(for: serverId)
            let entries: [WatchEntityEntry] = serverEntities
                .filter { entity in
                    entity.isWatchCompatible(allowedDomains: allowedDomains, excludedEntityIds: excluded)
                        && isIncluded(entity, devices[entity.entityId])
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .compactMap { entity in
                    let item = MagicItem(id: entity.entityId, serverId: serverId, type: .entity)
                    guard let info = provider.getInfo(for: item) else { return nil }
                    return WatchEntityEntry(
                        item: item,
                        info: info,
                        // A device the registry gives no name to has nothing to title a section
                        // with, so its entities stay loose rows rather than sitting under an id.
                        device: devices[entity.entityId].flatMap { device in
                            device.resolvedName.map { name in
                                WatchEntityEntry.Device(
                                    id: device.deviceId,
                                    name: name,
                                    parentId: device.parentDeviceId,
                                    parentName: device.parentDeviceId.flatMap { devicesById[$0]?.resolvedName }
                                )
                            }
                        }
                    )
                }
            // Controllable entities come first, ordered by most commonly used domain (then name —
            // `entries` is name-sorted, but Swift's sort isn't guaranteed stable); display-only
            // sensors keep the alphabetical order for their own section.
            let controls = entries
                .filter { !$0.item.isWatchDisplayOnly }
                .sorted { lhs, rhs in
                    let lhsIndex = Domain.watchAreaControlsSortIndex(for: lhs.item.domain)
                    let rhsIndex = Domain.watchAreaControlsSortIndex(for: rhs.item.domain)
                    if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
                    return lhs.info.name.localizedCaseInsensitiveCompare(rhs.info.name) == .orderedAscending
                }
            completion(.init(
                controls: .make(controls),
                sensors: .make(entries.filter(\.item.isWatchDisplayOnly))
            ))
        }
    }
}
