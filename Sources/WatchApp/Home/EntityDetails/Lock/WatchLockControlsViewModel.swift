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
    /// One of the screen's three buttons, used to mark which command is currently in flight.
    enum Action {
        case lock
        case unlock
        case open
    }

    @Published private(set) var entity: HAEntity?
    /// True when the state couldn't be refreshed recently — the screen shows a warning instead of
    /// presenting the state as current.
    @Published private(set) var isStale = false
    /// The command waiting on the server, if any. The command travels over REST and can take a
    /// while on a poor connection, so its button shows a spinner and every button stays disabled
    /// until the server answers — both to signal the wait and to keep a second tap from queueing
    /// another call.
    @Published private(set) var pendingAction: Action?

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
    /// entity unless the user explicitly picked a custom icon.
    var icon: MaterialDesignIcons {
        if let entity, itemInfo.customization?.iconIsCustomized != true {
            return entity.getMDI()
        }
        return item.icon(info: itemInfo)
    }

    /// The color follows the entity's state whichever icon is drawn, so a custom icon still shows
    /// whether the thing is on. Only a custom *color* overrides it, and only while active.
    var iconColor: UIColor {
        if let entity {
            let customColor = itemInfo.customization?.customIconColor.map { UIColor(hex: $0) }
            return entity.stateIconColor(customColor: customColor) ?? .white
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
        guard pendingAction == nil, let state = knownState else { return false }
        return ![.locked, .locking].contains(state)
    }

    /// Unlocking is pointless when already unlocked (or on the way there / open), and impossible
    /// while the state is unknown.
    var canUnlock: Bool {
        guard pendingAction == nil, let state = knownState else { return false }
        return ![.unlocked, .unlocking, .open, .opening].contains(state)
    }

    /// Open (unlatch) works from any known state — e.g. a Nuki can unlatch a locked door —
    /// but never blind.
    var canOpen: Bool {
        pendingAction == nil && knownState != nil
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
        send(service: .lock, action: .lock)
    }

    func unlock() {
        send(service: .unlock, action: .unlock)
    }

    func open() {
        send(service: .open, action: .open)
    }

    // MARK: - Private

    /// The current state, but only when it's an actionable one — unknown/unavailable answer nil
    /// so every button disables.
    private var knownState: Domain.State? {
        guard let entity, let state = Domain.State(rawValue: entity.state) else { return nil }
        if [.unknown, .unavailable].contains(state) { return nil }
        return state
    }

    /// Marks the action as pending for the whole round trip, so the screen can show the wait, and
    /// clears it once the server answers — `WatchServiceCallSender` always calls back (it fails the
    /// call on its own token and request deadlines), so the spinner can't outlive the request.
    ///
    /// Every action also answers on the wrist: a click when the command leaves, then success or
    /// failure once the server replies.
    private func send(service: Service, action: Action) {
        guard pendingAction == nil else { return }
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == item.serverId }) else {
            Current.Log.error("Server \(item.serverId) not synced to the watch for lock controls")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        pendingAction = action
        // Same tap feedback the home rows give when an execution starts.
        WKInterfaceDevice.current().play(.click)
        WatchServiceCallSender.send(
            domain: .lock,
            service: service,
            entityId: item.id,
            server: server
        ) { [weak self] success in
            // Called on the main queue by the sender.
            self?.pendingAction = nil
            if success {
                WKInterfaceDevice.current().play(.success)
                // Reflect the executed command quickly instead of waiting a full poll interval.
                self?.poller.refresh(after: 1)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
