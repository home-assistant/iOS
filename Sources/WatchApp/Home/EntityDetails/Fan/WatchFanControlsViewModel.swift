import Foundation
import HAKit
import Shared
import UIKit
import WatchKit

/// Backs the fan controls screen: power toggle and speed percentage.
///
/// Mirrors `WatchLightControlsViewModel`: state stays fresh through the shared REST polling
/// (`WatchEntityStatePoller`), commands go out as fan service REST calls
/// (`WatchServiceCallSender`), slider changes are debounced, and poll snapshots are held off
/// briefly after the user touches a control so the just-set value doesn't snap back.
final class WatchFanControlsViewModel: ObservableObject {
    @Published private(set) var entity: HAEntity?
    /// True when the state couldn't be refreshed recently — the screen shows a warning instead of
    /// presenting the values as current.
    @Published private(set) var isStale = false
    @Published private(set) var isOn = false
    /// 0–100. Owned by the user while interacting (see `pollHoldoffUntil`), by polling otherwise.
    @Published var speedPercentage: Double = 0

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private let poller: WatchEntityStatePoller
    private var speedDebounce: DispatchWorkItem?
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

    var capabilities: FanCapabilities? {
        entity.map(FanCapabilities.init(entity:))
    }

    /// The fan's speed granularity — many fans only do e.g. 25/50/75/100.
    var speedStep: Double {
        capabilities?.percentageStep ?? 1
    }

    var stateText: String? {
        guard let entity, let domain = item.domain else { return nil }
        return domain.contextualStateDescription(for: entity)
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
                apply(entity: entity)
            }
            isStale = snapshot.isStale
        }
    }

    func stopStateUpdates() {
        poller.stop()
    }

    // MARK: - Commands

    func setPower(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        holdOffPolling()
        send(service: on ? .turnOn : .turnOff)
    }

    /// Called for every slider tick; the actual service call waits until the value settles.
    /// `fan.set_percentage` with 0 turns the fan off, like the frontend.
    func setSpeed(_ percentage: Double) {
        speedPercentage = percentage
        isOn = percentage > 0
        holdOffPolling()
        speedDebounce?.cancel()
        // Rounded, not truncated: a 24.999 from slider float math should send 25.
        speedDebounce = debouncedSend(service: .setPercentage, data: ["percentage": Int(percentage.rounded())])
    }

    // MARK: - Private

    private func apply(entity: HAEntity) {
        self.entity = entity
        // The user's in-flight adjustments own the controls until the server catches up.
        guard pollHoldoffUntil.map({ Current.date() >= $0 }) ?? true else { return }
        isOn = entity.state == Domain.State.on.rawValue
        if let percentage = FanCapabilities(entity: entity).speedPercentage {
            speedPercentage = percentage
        } else if !isOn {
            speedPercentage = 0
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
            Current.Log.error("Server \(serverId) not synced to the watch for fan controls")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        WatchServiceCallSender.send(
            domain: .fan,
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
