import Foundation
import HAKit
import Shared
import UIKit
import WatchKit

/// Backs the light controls screen: power toggle, brightness and color temperature.
///
/// State stays fresh through the same REST polling the home rows use (`WatchEntityStatePoller`);
/// commands go out as `light.turn_on` / `light.turn_off` REST calls (`WatchServiceCallSender`).
/// Slider changes are debounced so dragging doesn't flood the server, and poll snapshots are held
/// off briefly after the user touches a control so the just-set value doesn't snap back before the
/// server reports it.
final class WatchLightControlsViewModel: ObservableObject {
    @Published private(set) var entity: HAEntity?
    /// True when the state couldn't be refreshed recently — the screen shows a warning instead of
    /// presenting the values as current.
    @Published private(set) var isStale = false
    @Published private(set) var isOn = false
    /// 0–100. Owned by the user while interacting (see `pollHoldoffUntil`), by polling otherwise.
    @Published var brightnessPercentage: Double = 0
    /// Kelvin, within `colorTempRange`.
    @Published var colorTempKelvin: Double = LightCapabilities.defaultMinColorTempKelvin

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private let poller: WatchEntityStatePoller
    private var brightnessDebounce: DispatchWorkItem?
    private var colorTempDebounce: DispatchWorkItem?
    /// While set and in the future, poll snapshots don't overwrite the user-facing control values —
    /// the user just changed them and the server hasn't caught up yet.
    private var pollHoldoffUntil: Date?

    private static let sendDebounceInterval: TimeInterval = 0.4
    private static let pollHoldoffInterval: TimeInterval = 3

    /// - Parameter initialEntity: the row's last polled snapshot, so the screen opens with current
    ///   values instead of waiting for its own first fetch.
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

    var capabilities: LightCapabilities? {
        entity.map(LightCapabilities.init(entity:))
    }

    var colorTempRange: ClosedRange<Double> {
        let min = capabilities?.minColorTempKelvin ?? LightCapabilities.defaultMinColorTempKelvin
        let max = capabilities?.maxColorTempKelvin ?? LightCapabilities.defaultMaxColorTempKelvin
        guard min < max else {
            return LightCapabilities.defaultMinColorTempKelvin ... LightCapabilities.defaultMaxColorTempKelvin
        }
        return min ... max
    }

    var stateText: String? {
        guard let entity, let domain = item.domain else { return nil }
        return domain.contextualStateDescription(for: entity)
    }

    /// Same live-icon rule as the home row: lights have a state-dependent icon, so render from the
    /// entity unless the user explicitly picked a custom icon.
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

    func setPower(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        holdOffPolling()
        send(service: on ? .turnOn : .turnOff)
    }

    /// Called for every slider tick; the actual service call waits until the value settles.
    func setBrightness(_ percentage: Double) {
        brightnessPercentage = percentage
        // Any brightness above zero turns the light on — mirror that immediately.
        isOn = percentage > 0
        holdOffPolling()
        brightnessDebounce?.cancel()
        brightnessDebounce = debouncedSend(data: ["brightness_pct": Int(percentage)])
    }

    /// Discrete swatch taps need no debounce. `light.turn_on` with a color also turns the light
    /// on, like the frontend.
    func setColor(hex: String) {
        isOn = true
        holdOffPolling()
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(hex: hex).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        send(service: .turnOn, data: [
            "rgb_color": [Int(red * 255), Int(green * 255), Int(blue * 255)],
        ])
    }

    /// Called for every slider tick; the actual service call waits until the value settles.
    /// `light.turn_on` with a color temperature also turns the light on, like the frontend.
    func setColorTemp(_ kelvin: Double) {
        colorTempKelvin = kelvin
        isOn = true
        holdOffPolling()
        colorTempDebounce?.cancel()
        colorTempDebounce = debouncedSend(data: ["color_temp_kelvin": Int(kelvin)])
    }

    // MARK: - Private

    private func apply(entity: HAEntity) {
        self.entity = entity
        // The user's in-flight adjustments own the controls until the server catches up.
        guard pollHoldoffUntil.map({ Current.date() >= $0 }) ?? true else { return }
        isOn = entity.state == Domain.State.on.rawValue
        let capabilities = LightCapabilities(entity: entity)
        if let percentage = capabilities.brightnessPercentage {
            brightnessPercentage = percentage
        } else if !isOn {
            brightnessPercentage = 0
        }
        if let kelvin = capabilities.colorTempKelvin {
            colorTempKelvin = kelvin.clamped(to: colorTempRange)
        }
    }

    private func holdOffPolling() {
        pollHoldoffUntil = Current.date().addingTimeInterval(Self.pollHoldoffInterval)
    }

    private func send(service: Service, data: [String: Any] = [:]) {
        Self.sendCommand(entityId: item.id, serverId: item.serverId, service: service, data: data, poller: poller)
    }

    /// Slider debounces reference the command through this, capturing only values — so an
    /// adjustment made right before dismissing the screen still reaches the server after the
    /// view model is gone.
    private func debouncedSend(data: [String: Any]) -> DispatchWorkItem {
        let entityId = item.id
        let serverId = item.serverId
        let workItem = DispatchWorkItem { [weak poller] in
            Self.sendCommand(entityId: entityId, serverId: serverId, service: .turnOn, data: data, poller: poller)
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
            Current.Log.error("Server \(serverId) not synced to the watch for light controls")
            WKInterfaceDevice.current().play(.failure)
            return
        }
        WatchServiceCallSender.send(
            domain: .light,
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

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
