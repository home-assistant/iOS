import Foundation
import HAKit
import PromiseKit
import Shared

final class CarPlayClimateControlViewModel {
    /// Controls whose just-changed value should win over incoming snapshots until the server
    /// echoes the change back, so a stale state event doesn't bounce the UI.
    enum PendingControl: Hashable {
        case targetTemperature
        case targetTemperatureRange
        case targetHumidity
    }

    /// Rapid +/- taps coalesce into a single service call.
    private static let sendDebounceInterval: TimeInterval = 0.8
    /// How long an optimistic value shields against incoming snapshots once its send fired.
    private static let pendingProtectionInterval: TimeInterval = 3

    let server: Server
    let entityId: String
    /// Screen title: CPListTemplate's title is fixed at init, so resolve the best name up front —
    /// the caller-provided display name (e.g. the magic item's configured name, available even when
    /// the entity state hasn't arrived yet), else the entity's friendly name. The raw entity id is
    /// the last resort only.
    let title: String
    private(set) var control: ClimateControlState
    weak var templateProvider: CarPlayClimateControlTemplate?

    private var pendingControls: Set<PendingControl> = []
    private var debounceWorkItems: [PendingControl: DispatchWorkItem] = [:]
    private var pendingClearWorkItems: [PendingControl: DispatchWorkItem] = [:]

    init(server: Server, entity: HAEntity, displayName: String? = nil) {
        self.server = server
        self.entityId = entity.entityId
        self.title = displayName ?? entity.attributes.friendlyName ?? entity.entityId
        self.control = ClimateControlState(entity: entity)
    }

    func updateStates(serverId: String, entities: HACachedStates) {
        guard serverId == server.identifier.rawValue, let entity = entities[entityId] else { return }
        var updated = ClimateControlState(entity: entity)
        // Keep the values the user just changed until the server echoes them back.
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
        control = updated
        templateProvider?.refreshDisplayedValues()
    }

    // MARK: - Target temperature

    func adjustTargetTemperature(by direction: Double) {
        let base = control.targetTemperature ?? control.currentTemperature ?? control.minTemperature
        control.targetTemperature = control.clampTemperature(base + direction * control.temperatureStep)
        markPending(.targetTemperature)
        scheduleSend(for: .targetTemperature) { [weak self] in
            guard let self, let target = control.targetTemperature else { return }
            send(service: .setTemperature, data: ["temperature": target])
        }
        templateProvider?.refreshDisplayedValues()
    }

    func adjustTargetTemperatureLow(by direction: Double) {
        let base = control.targetTemperatureLow ?? control.minTemperature
        var value = control.clampTemperature(base + direction * control.temperatureStep)
        if let high = control.targetTemperatureHigh {
            value = min(value, high)
        }
        control.targetTemperatureLow = value
        scheduleRangeSend()
    }

    func adjustTargetTemperatureHigh(by direction: Double) {
        let base = control.targetTemperatureHigh ?? control.maxTemperature
        var value = control.clampTemperature(base + direction * control.temperatureStep)
        if let low = control.targetTemperatureLow {
            value = max(value, low)
        }
        control.targetTemperatureHigh = value
        scheduleRangeSend()
    }

    private func scheduleRangeSend() {
        markPending(.targetTemperatureRange)
        scheduleSend(for: .targetTemperatureRange) { [weak self] in
            guard let self,
                  let low = control.targetTemperatureLow,
                  let high = control.targetTemperatureHigh else { return }
            // Home Assistant requires both bounds in the same call.
            send(service: .setTemperature, data: ["target_temp_low": low, "target_temp_high": high])
        }
        templateProvider?.refreshDisplayedValues()
    }

    // MARK: - Target humidity

    func adjustTargetHumidity(by direction: Double) {
        let base = control.targetHumidity ?? control.currentHumidity ?? control.minHumidity
        control.targetHumidity = control.clampHumidity(base + direction * ClimateControlState.humidityStep)
        markPending(.targetHumidity)
        scheduleSend(for: .targetHumidity) { [weak self] in
            guard let self, let target = control.targetHumidity else { return }
            send(service: .setHumidity, data: ["humidity": target])
        }
        templateProvider?.refreshDisplayedValues()
    }

    // MARK: - Modes

    func setHvacMode(_ mode: String) {
        control.hvacMode = mode
        send(service: .setHvacMode, data: ["hvac_mode": mode])
        templateProvider?.refreshDisplayedValues()
    }

    func setFanMode(_ mode: String) {
        control.fanMode = mode
        send(service: .setFanMode, data: ["fan_mode": mode])
        templateProvider?.refreshDisplayedValues()
    }

    func setSwingMode(_ mode: String) {
        control.swingMode = mode
        send(service: .setSwingMode, data: ["swing_mode": mode])
        templateProvider?.refreshDisplayedValues()
    }

    func setSwingHorizontalMode(_ mode: String) {
        control.swingHorizontalMode = mode
        send(service: .setSwingHorizontalMode, data: ["swing_horizontal_mode": mode])
        templateProvider?.refreshDisplayedValues()
    }

    func setPresetMode(_ mode: String) {
        control.presetMode = mode
        send(service: .setPresetMode, data: ["preset_mode": mode])
        templateProvider?.refreshDisplayedValues()
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
            // Shield the optimistic value a little longer so the state event triggered by the send
            // (which may still carry the old target) doesn't bounce the UI back.
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
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available for CarPlay climate service call on \(entityId)")
            return
        }
        connection.send(.callClimateService(service, entityId: entityId, data: data)).promise
            .done { _ in
                Current.Log.verbose("CarPlay climate \(service.rawValue) succeeded for \(self.entityId)")
            }
            .catch { [weak self] error in
                guard let self else { return }
                Current.Log.error("CarPlay climate \(service.rawValue) failed for \(entityId): \(error)")
            }
    }
}
