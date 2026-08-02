import Foundation
import HAKit
import Shared
import UIKit
import WatchKit

/// Backs the vacuum controls screen: start/pause/stop/return to dock plus fan speed.
///
/// Mirrors `WatchCoverControlsViewModel`: state stays fresh through the shared REST polling
/// (`WatchEntityStatePoller`) and commands go out as vacuum service REST calls
/// (`WatchServiceCallSender`). There is nothing continuous to debounce — every control is an
/// explicit button or a single-choice pick.
final class WatchVacuumControlsViewModel: ObservableObject {
    @Published private(set) var entity: HAEntity?
    /// True when the state couldn't be refreshed recently — the screen shows a warning instead of
    /// presenting the values as current.
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

    var capabilities: VacuumCapabilities? {
        entity.map(VacuumCapabilities.init(entity:))
    }

    var stateText: String? {
        guard let entity, let domain = item.domain else { return nil }
        return domain.contextualStateDescription(for: entity)
    }

    /// Whether the vacuum is actively cleaning, which flips the primary button to pause.
    var isCleaning: Bool {
        entity?.state == "cleaning"
    }

    var icon: MaterialDesignIcons {
        item.icon(info: itemInfo)
    }

    var iconColor: UIColor {
        if let hex = itemInfo.customization?.iconColor {
            return UIColor(hex: hex)
        }
        return .white
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

    func start() {
        send(service: .start)
    }

    func pause() {
        send(service: .pause)
    }

    func stop() {
        send(service: .stop)
    }

    func returnToBase() {
        send(service: .returnToBase)
    }

    func locate() {
        send(service: .locate)
    }

    func setFanSpeed(_ speed: String) {
        send(service: .setFanSpeed, data: ["fan_speed": speed])
    }

    // MARK: - Private

    private func send(service: Service, data: [String: Any] = [:]) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == item.serverId }) else {
            Current.Log.error("Server \(item.serverId) not synced to the watch for vacuum controls")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        WKInterfaceDevice.current().play(.click)
        WatchServiceCallSender.send(
            domain: .vacuum,
            service: service,
            entityId: item.id,
            data: data,
            server: server
        ) { [weak poller] success in
            if success {
                // Reflect the executed command quickly instead of waiting a full poll interval.
                poller?.refresh(after: 1)
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
