import Foundation
import HAKit
import Shared
import UIKit
import WatchKit

/// Backs the lock screen: state-colored icon, current state, and the lock/unlock/open actions.
///
/// Locks are security-sensitive, so their row never toggles directly — every tap lands here and
/// the action is an explicit button press. Which buttons are enabled follows the live state: you
/// can't lock a locked lock or unlock an unlocked one, and everything is disabled until the first
/// state fetch answers (acting blind on a lock is worse than waiting a second).
final class WatchLockControlsViewModel: ObservableObject {
    @Published private(set) var entity: HAEntity?
    /// True when the state couldn't be refreshed recently — the screen shows a warning instead of
    /// presenting the state as current.
    @Published private(set) var isStale = false

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private let poller: WatchEntityStatePoller

    /// The view model is built inside `StateObject`'s autoclosure by its screen, so creation
    /// (and its poller) is deferred until the screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self.item = item
        self.itemInfo = itemInfo
        self.poller = WatchEntityStatePoller(entityId: item.id, serverId: item.serverId)
        self.entity = initialEntity
    }

    var name: String {
        item.name(info: itemInfo)
    }

    var stateText: String? {
        guard let entity, let domain = item.domain else { return nil }
        return domain.contextualStateDescription(for: entity)
    }

    /// Same live-icon rule as the home row: locks have a state-dependent icon, so render from the
    /// entity unless the user explicitly picked a custom icon. The color codes the state (locked
    /// vs. unlocked vs. jammed) through the shared entity color provider.
    var icon: MaterialDesignIcons {
        if let entity, itemInfo.customization?.iconIsCustomized != true {
            return entity.getMDI()
        }
        return item.icon(info: itemInfo)
    }

    var iconColor: UIColor {
        if let entity, itemInfo.customization?.iconIsCustomized != true {
            return entity.carPlayIconColor() ?? .white
        }
        if let hex = itemInfo.customization?.iconColor {
            return UIColor(hex: hex)
        }
        return .white
    }

    /// Whether the lock advertises `lock.open` (unlatch) — mirrors the frontend's feature check.
    var supportsOpen: Bool {
        guard let entity else { return false }
        return LockCapabilities(entity: entity).supportsOpen
    }

    /// Locking is pointless when already locked (or on the way there), and impossible while the
    /// state is unknown.
    var canLock: Bool {
        guard let state = knownState else { return false }
        return ![.locked, .locking].contains(state)
    }

    /// Unlocking is pointless when already unlocked (or on the way there / open), and impossible
    /// while the state is unknown.
    var canUnlock: Bool {
        guard let state = knownState else { return false }
        return ![.unlocked, .unlocking, .open, .opening].contains(state)
    }

    /// Open (unlatch) works from any known state — e.g. a Nuki can unlatch a locked door —
    /// but never blind.
    var canOpen: Bool {
        knownState != nil
    }

    func startStateUpdates() {
        poller.start { [weak self] snapshot in
            guard let self else { return }
            if let entity = snapshot.entity {
                self.entity = entity
            }
            isStale = snapshot.isStale
        }
    }

    func stopStateUpdates() {
        poller.stop()
    }

    // MARK: - Commands

    func lock() {
        send(service: .lock)
    }

    func unlock() {
        send(service: .unlock)
    }

    func open() {
        send(service: .open)
    }

    // MARK: - Private

    /// The current state, but only when it's an actionable one — unknown/unavailable answer nil
    /// so every button disables.
    private var knownState: Domain.State? {
        guard let entity, let state = Domain.State(rawValue: entity.state) else { return nil }
        if [.unknown, .unavailable].contains(state) { return nil }
        return state
    }

    /// Every action answers on the wrist: a click when the command leaves, then success or failure
    /// once the server replies. The screen's own state can take a poll interval to catch up, so
    /// without haptics a lock command looks like it did nothing.
    private func send(service: Service) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == item.serverId }) else {
            Current.Log.error("Server \(item.serverId) not synced to the watch for lock controls")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        WKInterfaceDevice.current().play(.click)
        WatchServiceCallSender.send(
            domain: .lock,
            service: service,
            entityId: item.id,
            server: server
        ) { [weak poller] success in
            if success {
                WKInterfaceDevice.current().play(.success)
                // Reflect the executed command quickly instead of waiting a full poll interval.
                poller?.refresh(after: 1)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
