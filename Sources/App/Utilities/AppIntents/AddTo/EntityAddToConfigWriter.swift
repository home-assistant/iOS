import Foundation
import Shared

/// Writes an entity into the configs behind the "add to" destinations, so running the App Intent adds
/// exactly what the frontend's "Add to" sheet adds — the same `MagicItem`, in the same list.
///
/// Where that sheet opens the destination's configuration screen with the entity filled in, this
/// finishes the job outright: an intent has no screen to hand anyone, and "add this to my watch" is
/// only worth saying if saying it is enough.
@available(macOS 13.0, *)
enum EntityAddToConfigWriter {
    /// What the write did, so the caller can tell someone their entity was added without claiming to
    /// have added it twice.
    enum Outcome: Equatable {
        case added
        case alreadyPresent
    }

    static func add(
        entityId: String,
        serverId: String,
        to destination: EntityAddToDestinationAppEnum
    ) throws -> Outcome {
        switch destination {
        case .appleWatch: return try addToWatch(entityId: entityId, serverId: serverId)
        case .carPlay: return try addToCarPlay(entityId: entityId, serverId: serverId)
        case .macToolbar: return try addToMacToolbar(entityId: entityId, serverId: serverId)
        }
    }

    private static func addToWatch(entityId: String, serverId: String) throws -> Outcome {
        var config = try WatchConfig.config() ?? WatchConfig()
        guard !config.items.contains(entityId: entityId, serverId: serverId) else { return .alreadyPresent }

        config.items.append(MagicItem(id: entityId, serverId: serverId, type: .entity))
        config.stampModified()
        try Current.database().write { db in
            if config.id != WatchConfig.watchConfigId {
                // Watch configs predate the static id, so a row written back then would be left behind
                // as a second config rather than replaced. Same handling as the configuration screen.
                try WatchConfig.deleteAll(db)
                config.id = WatchConfig.watchConfigId
            }
            try config.insert(db, onConflict: .replace)
        }
        // The watch needs the new entity's registry row (display precision) to render it, the same way
        // it does when the configuration screen saves.
        WatchMirrorPushCoordinator.schedule(reason: .watchConfigChanged)
        return .added
    }

    private static func addToCarPlay(entityId: String, serverId: String) throws -> Outcome {
        var config = try CarPlayConfig.config() ?? CarPlayConfig()
        guard !config.quickAccessItems.contains(entityId: entityId, serverId: serverId) else {
            return .alreadyPresent
        }

        config.quickAccessItems.append(MagicItem(id: entityId, serverId: serverId, type: .entity))
        try Current.database().write { db in
            try config.insert(db, onConflict: .replace)
        }
        return .added
    }

    private static func addToMacToolbar(entityId: String, serverId: String) throws -> Outcome {
        var config = try MacToolbarConfig.config() ?? MacToolbarConfig()

        let item: MagicItem
        let outcome: Outcome
        if let existing = config.items.first(where: { $0.id == entityId && $0.serverId == serverId }) {
            item = existing
            outcome = .alreadyPresent
        } else {
            let appEntity = HAAppEntity.entity(id: entityId, serverId: serverId)
            let iconName = appEntity?.icon
                ?? Domain(rawValue: appEntity?.domain ?? "")?.icon(deviceClass: appEntity?.rawDeviceClass).name
                ?? MaterialDesignIcons.dotsGridIcon.name
            item = MagicItem(
                id: entityId,
                serverId: serverId,
                type: .entity,
                customization: .init(icon: iconName),
                action: .moreInfoDialog,
                displayText: appEntity?.name
            )
            config.items.append(item)
            try Current.database().write { db in
                try config.insert(db, onConflict: .replace)
            }
            outcome = .added
        }

        // Posted even for an entity already in the config, matching `EntityAddToHandler`: the config
        // keeps entities the user removed from the toolbar's own customization, and this notification
        // is what puts a retained one back on a visible toolbar.
        NotificationCenter.default.post(
            name: .macToolbarConfigDidChange,
            object: nil,
            userInfo: [MacToolbarConfigChange.userInfoKey: MacToolbarConfigChange.added(item)]
        )
        return outcome
    }
}

private extension [MagicItem] {
    /// An entity counts as already added when the same entity on the same server is anywhere in the
    /// list, folders included: the watch and CarPlay both let a folder hold entities, and a second
    /// copy at the root would still be a duplicate.
    ///
    /// The server is part of the match because two servers may well have a `light.kitchen` each, and
    /// both belong in a destination.
    func contains(entityId: String, serverId: String) -> Bool {
        contains { item in
            if item.id == entityId, item.serverId == serverId {
                return true
            }
            return item.items?.contains(entityId: entityId, serverId: serverId) ?? false
        }
    }
}
