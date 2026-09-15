#if !os(watchOS)
import Foundation

/// The line under a summary's title, which says something different for each of them: how many
/// lights are on, how warm the house is, whether anything is unlocked, what is playing, which
/// batteries are flat.
///
/// The port of `hui-home-summary-card`'s `_computeSummaryState`. Computed from the live states
/// rather than carried in the generated config, so a light going out changes the line without the
/// dashboard being generated again.
public enum HomeSummarySubtitle {
    /// What the maintenance panel treats as a battery worth telling somebody about.
    private static let lowBatteryThreshold = 20.0

    public static func subtitle(
        for summary: HomeSummaryKind,
        entityIds: [String],
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> String? {
        switch summary {
        case .light:
            return lights(entityIds, registry: registry, strings: strings)
        case .climate:
            return climate(registry: registry)
        case .security:
            return security(entityIds, registry: registry, strings: strings)
        case .mediaPlayers:
            return mediaPlayers(entityIds, registry: registry, strings: strings)
        case .maintenance:
            return maintenance(entityIds, registry: registry, strings: strings)
        case .persons:
            return persons(entityIds, registry: registry, strings: strings)
        case .energy, .weather:
            // Energy needs the day's consumption, which the app does not collect yet; weather is a
            // plain tile and says its own state.
            return nil
        }
    }

    private static func lights(
        _ entityIds: [String],
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> String {
        let on = entityIds.count { registry.state($0)?.state == "on" }
        return on > 0 ? strings.countLightsOn(on) : strings.allLightsOff
    }

    /// How warm the house is, as the range across the rooms that have a temperature — one figure
    /// when they agree.
    private static func climate(registry: HomeRegistry) -> String? {
        let temperatures = registry.areas
            .compactMap(\.temperatureEntityId)
            .compactMap { registry.state($0)?.state }
            .compactMap(Double.init)
        guard let lowest = temperatures.min(), let highest = temperatures.max() else {
            return nil
        }
        let low = format(lowest)
        let high = format(highest)
        return low == high ? "\(low)°" : "\(low) - \(high)°"
    }

    private static func format(_ temperature: Double) -> String {
        String(format: "%.1f", temperature)
    }

    /// Unlocked doors first, then disarmed alarms, and only "all secure" when there is neither.
    private static func security(
        _ entityIds: [String],
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> String? {
        let locks = entityIds.filter { HomeEntityID.domain(of: $0) == "lock" }
        let alarms = entityIds.filter { HomeEntityID.domain(of: $0) == "alarm_control_panel" }
        guard !locks.isEmpty || !alarms.isEmpty else {
            return nil
        }
        let unlocked = locks.count { entityId in
            ["unlocked", "jammed", "open"].contains(registry.state(entityId)?.state ?? "")
        }
        if unlocked > 0 {
            return strings.countLocksUnlocked(unlocked)
        }
        let disarmed = alarms.count { registry.state($0)?.state == "disarmed" }
        if disarmed > 0 {
            return strings.countAlarmsDisarmed(disarmed)
        }
        return strings.allSecure
    }

    private static func mediaPlayers(
        _ entityIds: [String],
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> String {
        let playing = entityIds.count { registry.state($0)?.state == "playing" }
        return playing > 0 ? strings.countMediaPlaying(playing) : strings.noMediaPlaying
    }

    /// Flat batteries and the devices that stopped answering, in that order, both when there are
    /// both.
    private static func maintenance(
        _ entityIds: [String],
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> String {
        let low = entityIds.count { isLowBattery($0, in: registry) }
        let unavailable = entityIds.count { registry.state($0)?.isUnavailable == true }
        let parts = [
            low > 0 ? strings.countLowBatteries(low) : nil,
            unavailable > 0 ? strings.countUnavailableDevices(unavailable) : nil,
        ].compactMap { $0 }
        return parts.isEmpty ? strings.allMaintenanceGood : parts.joined(separator: ", ")
    }

    /// The port of the frontend's `filterLowBatteryEntities`: a binary battery sensor is low when it
    /// is `on`, a numeric one when it has fallen to the threshold.
    private static func isLowBattery(_ entityId: String, in registry: HomeRegistry) -> Bool {
        guard let state = registry.state(entityId) else {
            return false
        }
        if state.domain == "binary_sensor" {
            return state.state == "on"
        }
        guard let level = Double(state.state) else {
            return false
        }
        return level <= lowBatteryThreshold
    }

    private static func persons(
        _ entityIds: [String],
        registry: HomeRegistry,
        strings: HomeDashboardStrings
    ) -> String {
        let home = entityIds.count { registry.state($0)?.state == "home" }
        return home > 0 ? strings.countPeopleHome(home) : strings.nobodyHome
    }
}
#endif
