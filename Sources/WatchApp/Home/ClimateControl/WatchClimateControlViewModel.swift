import Foundation
import HAKit
import Shared
import UIKit
import WatchKit

/// Backs the control screen a climate row opens when tapped.
///
/// Live state comes from the same REST polling every watch screen uses (`WatchEntityStatePoller`);
/// each snapshot is parsed into a `ClimateControlState`. Actions go out as `WatchServiceCall`s —
/// the watch cannot hold a WebSocket, so services are called over REST. Values the user just
/// changed are kept on screen (optimistically) until the server echoes them back, and rapid +/-
/// taps coalesce into a single service call.
final class WatchClimateControlViewModel: ObservableObject {
    /// Controls whose just-changed value should win over incoming snapshots until the server
    /// echoes the change back, so a stale poll doesn't bounce the UI.
    enum PendingControl: Hashable {
        case targetTemperature
        case targetTemperatureRange
        case targetHumidity
    }

    /// Rapid +/- taps coalesce into a single service call.
    private static let sendDebounceInterval: TimeInterval = 0.8
    /// How long an optimistic value shields against incoming snapshots once its send fired.
    private static let pendingProtectionInterval: TimeInterval = 3

    /// Nil until the first fetch succeeds — the screen shows a spinner meanwhile.
    @Published private(set) var control: ClimateControlState?
    /// The entity's friendly name from the latest snapshot; preferred for the screen title so it
    /// tracks the entity's actual name rather than a stale configured one (or the raw id).
    @Published private(set) var entityName: String?
    /// True when the state couldn't be refreshed recently, so the screen can say the values may be
    /// out of date instead of presenting them as current.
    @Published private(set) var isStale = false
    /// Set when a service call fails, so the failure isn't silent.
    @Published var errorMessage: String?

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private let poller: WatchEntityStatePoller
    private var pendingControls: Set<PendingControl> = []
    private var debounceWorkItems: [PendingControl: DispatchWorkItem] = [:]
    private var pendingClearWorkItems: [PendingControl: DispatchWorkItem] = [:]

    /// - Parameter initialEntity: a snapshot to render right away, used by previews so the screen
    ///   shows real content without a server. Polling replaces it as soon as it fetches.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self.item = item
        self.itemInfo = itemInfo
        self.poller = WatchEntityStatePoller(entityId: item.id, serverId: item.serverId)
        self.control = initialEntity.map(ClimateControlState.init(entity:))
        self.entityName = initialEntity?.attributes.friendlyName
    }

    /// The entity's live friendly name, falling back to the name configured for the item.
    var name: String {
        entityName ?? item.name(info: itemInfo)
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
            isStale = snapshot.isStale
            guard let entity = snapshot.entity else { return }
            entityName = entity.attributes.friendlyName ?? entityName
            var updated = ClimateControlState(entity: entity)
            // Keep the values the user just changed until the server echoes them back.
            if let control {
                if pendingControls.contains(.targetTemperature) {
                    updated.targetTemperature = control.targetTemperature
                }
                if pendingControls.contains(.targetTemperatureRange) {
                    updated.targetTemperatureLow = control.targetTemperatureLow
                    updated.targetTemperatureHigh = control.targetTemperatureHigh
                }
                if pendingControls.contains(.targetHumidity) {
                    updated.targetHumidity = control.targetHumidity
                }
            }
            control = updated
        }
    }

    func stopStateUpdates() {
        poller.stop()
    }

    // MARK: - Target temperature

    func adjustTargetTemperature(by direction: Double) {
        guard var control else { return }
        let base = control.targetTemperature ?? control.currentTemperature ?? control.minTemperature
        control.targetTemperature = control.clampTemperature(base + direction * control.temperatureStep)
        self.control = control
        markPending(.targetTemperature)
        scheduleSend(for: .targetTemperature) { [weak self] in
            guard let self, let target = self.control?.targetTemperature else { return }
            send(service: .setTemperature, data: ["temperature": target])
        }
    }

    func adjustTargetTemperatureLow(by direction: Double) {
        guard var control else { return }
        let base = control.targetTemperatureLow ?? control.minTemperature
        var value = control.clampTemperature(base + direction * control.temperatureStep)
        if let high = control.targetTemperatureHigh {
            value = min(value, high)
        }
        control.targetTemperatureLow = value
        self.control = control
        scheduleRangeSend()
    }

    func adjustTargetTemperatureHigh(by direction: Double) {
        guard var control else { return }
        let base = control.targetTemperatureHigh ?? control.maxTemperature
        var value = control.clampTemperature(base + direction * control.temperatureStep)
        if let low = control.targetTemperatureLow {
            value = max(value, low)
        }
        control.targetTemperatureHigh = value
        self.control = control
        scheduleRangeSend()
    }

    private func scheduleRangeSend() {
        markPending(.targetTemperatureRange)
        scheduleSend(for: .targetTemperatureRange) { [weak self] in
            guard let self,
                  let low = control?.targetTemperatureLow,
                  let high = control?.targetTemperatureHigh else { return }
            // Home Assistant requires both bounds in the same call.
            send(service: .setTemperature, data: ["target_temp_low": low, "target_temp_high": high])
        }
    }

    // MARK: - Target humidity

    func adjustTargetHumidity(by direction: Double) {
        guard var control else { return }
        let base = control.targetHumidity ?? control.currentHumidity ?? control.minHumidity
        control.targetHumidity = control.clampHumidity(base + direction * ClimateControlState.humidityStep)
        self.control = control
        markPending(.targetHumidity)
        scheduleSend(for: .targetHumidity) { [weak self] in
            guard let self, let target = self.control?.targetHumidity else { return }
            send(service: .setHumidity, data: ["humidity": target])
        }
    }

    // MARK: - Modes

    func setHvacMode(_ mode: String) {
        control?.hvacMode = mode
        send(service: .setHvacMode, data: ["hvac_mode": mode])
    }

    func setFanMode(_ mode: String) {
        control?.fanMode = mode
        send(service: .setFanMode, data: ["fan_mode": mode])
    }

    func setSwingMode(_ mode: String) {
        control?.swingMode = mode
        send(service: .setSwingMode, data: ["swing_mode": mode])
    }

    func setSwingHorizontalMode(_ mode: String) {
        control?.swingHorizontalMode = mode
        send(service: .setSwingHorizontalMode, data: ["swing_horizontal_mode": mode])
    }

    func setPresetMode(_ mode: String) {
        control?.presetMode = mode
        send(service: .setPresetMode, data: ["preset_mode": mode])
    }

    // MARK: - Sending

    private func markPending(_ pendingControl: PendingControl) {
        pendingControls.insert(pendingControl)
    }

    private func scheduleSend(for pendingControl: PendingControl, _ send: @escaping () -> Void) {
        debounceWorkItems[pendingControl]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            debounceWorkItems[pendingControl] = nil
            send()
            // Shield the optimistic value a little longer so a poll racing the send (still carrying
            // the old target) doesn't bounce the UI back.
            pendingClearWorkItems[pendingControl]?.cancel()
            let clearWorkItem = DispatchWorkItem { [weak self] in
                self?.pendingClearWorkItems[pendingControl] = nil
                self?.pendingControls.remove(pendingControl)
            }
            pendingClearWorkItems[pendingControl] = clearWorkItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.pendingProtectionInterval,
                execute: clearWorkItem
            )
        }
        debounceWorkItems[pendingControl] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sendDebounceInterval, execute: workItem)
    }

    private func send(service: Service, data: [String: Any]) {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == item.serverId }) else {
            Current.Log.error("Server \(item.serverId) not synced to the watch for climate control")
            errorMessage = L10n.Watch.Home.Run.Error.message
            return
        }
        var serviceData = data
        serviceData["entity_id"] = item.id
        let call = WatchServiceCall(
            domain: Domain.climate.rawValue,
            service: service.rawValue,
            data: serviceData
        )
        WKInterfaceDevice.current().play(.click)
        call.execute(on: server, logLabel: item.id) { [weak self] success, error in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if success {
                    // Reflect the executed change quickly instead of waiting a full poll interval.
                    poller.refresh(after: 1)
                } else {
                    Current.Log.error(
                        "Climate service \(service.rawValue) failed for \(item.id): " +
                            "\(error?.localizedDescription ?? "unknown")"
                    )
                    WKInterfaceDevice.current().play(.failure)
                    errorMessage = error?.localizedDescription ?? L10n.Watch.Home.Run.Error.message
                }
            }
        }
    }
}
