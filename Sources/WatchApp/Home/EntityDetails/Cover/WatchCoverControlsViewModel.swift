import Foundation
import HAKit
import Shared
import UIKit
import WatchKit

/// Backs the cover controls screen: position slider plus open/stop/close.
///
/// Mirrors `WatchLightControlsViewModel`: state stays fresh through the shared REST polling
/// (`WatchEntityStatePoller`), commands go out as cover service REST calls
/// (`WatchServiceCallSender`), slider changes are debounced, and poll snapshots are held off
/// briefly after the user touches a control so the just-set value doesn't snap back.
final class WatchCoverControlsViewModel: ObservableObject {
    @Published private(set) var entity: HAEntity?
    /// True when the state couldn't be refreshed recently — the screen shows a warning instead of
    /// presenting the values as current.
    @Published private(set) var isStale = false
    /// 0 (closed) – 100 (open). Owned by the user while interacting (see `pollHoldoffUntil`).
    @Published var position: Double = 0

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private let poller: WatchEntityStatePoller
    private var positionDebounce: DispatchWorkItem?
    /// While set and in the future, poll snapshots don't overwrite the user-facing control values.
    private var pollHoldoffUntil: Date?

    private static let sendDebounceInterval: TimeInterval = 0.4
    private static let pollHoldoffInterval: TimeInterval = 3

    /// The view model is built inside `StateObject`'s autoclosure by its screen, so creation
    /// (and its poller) is deferred until the screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self.item = item
        self.itemInfo = itemInfo
        self.poller = WatchEntityStatePoller(entityId: item.id, serverId: item.serverId)
        if let initialEntity {
            apply(entity: initialEntity)
        }
    }

    var name: String {
        item.name(info: itemInfo)
    }

    var capabilities: CoverCapabilities? {
        entity.map(CoverCapabilities.init(entity:))
    }

    var stateText: String? {
        guard let entity, let domain = item.domain else { return nil }
        return domain.contextualStateDescription(for: entity)
    }

    /// Same live-icon rule as the home row: covers have a state-dependent icon, so render from
    /// the entity unless the user explicitly picked a custom icon.
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

    func startStateUpdates() {
        poller.start { [weak self] snapshot in
            guard let self else { return }
            if let entity = snapshot.entity {
                apply(entity: entity)
            }
            isStale = snapshot.isStale
        }
    }

    func stopStateUpdates() {
        poller.stop()
    }

    // MARK: - Commands

    func open() {
        holdOffPolling()
        send(service: .openCover)
    }

    func close() {
        holdOffPolling()
        send(service: .closeCover)
    }

    func stop() {
        holdOffPolling()
        send(service: .stopCover)
    }

    /// Called for every slider tick; the actual service call waits until the value settles.
    func setPosition(_ value: Double) {
        position = value
        holdOffPolling()
        positionDebounce?.cancel()
        positionDebounce = debouncedSend(service: .setCoverPosition, data: ["position": Int(value)])
    }

    // MARK: - Private

    private func apply(entity: HAEntity) {
        self.entity = entity
        // The user's in-flight adjustments own the controls until the server catches up.
        guard pollHoldoffUntil.map({ Current.date() >= $0 }) ?? true else { return }
        if let currentPosition = CoverCapabilities(entity: entity).currentPosition {
            position = currentPosition
        }
    }

    private func holdOffPolling() {
        pollHoldoffUntil = Current.date().addingTimeInterval(Self.pollHoldoffInterval)
    }

    private func send(service: Service, data: [String: Any] = [:]) {
        Self.sendCommand(entityId: item.id, serverId: item.serverId, service: service, data: data, poller: poller)
    }

    /// Slider debounces reference the command through this, capturing only values — so an
    /// adjustment made right before leaving the screen still reaches the server after the view
    /// model is gone.
    private func debouncedSend(service: Service, data: [String: Any]) -> DispatchWorkItem {
        let entityId = item.id
        let serverId = item.serverId
        let workItem = DispatchWorkItem { [weak poller] in
            Self.sendCommand(entityId: entityId, serverId: serverId, service: service, data: data, poller: poller)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sendDebounceInterval, execute: workItem)
        return workItem
    }

    private static func sendCommand(
        entityId: String,
        serverId: String,
        service: Service,
        data: [String: Any],
        poller: WatchEntityStatePoller?
    ) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            Current.Log.error("Server \(serverId) not synced to the watch for cover controls")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        WatchServiceCallSender.send(
            domain: .cover,
            service: service,
            entityId: entityId,
            data: data,
            server: server
        ) { success in
            if success {
                // Reflect the executed command quickly instead of waiting a full poll interval.
                poller?.refresh(after: 1)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
