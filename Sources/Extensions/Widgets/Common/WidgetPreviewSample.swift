import Foundation
import Shared

/// Fixed sample content used to render widgets in the iOS widget gallery.
///
/// WidgetKit asks for a snapshot with `context.isPreview` set while the user browses the picker,
/// and it does so for every widget the extension ships, in every supported family, before anything
/// has been configured. Building those previews from live data means database reads, cache files
/// and server round trips inside the extension's tight time and memory budget — all to draw
/// something that isn't the user's data anyway. Providers serve this sample instead, the same way
/// the energy widget does.
///
/// Every user visible string comes from a table the app already translates (`CoreStrings`,
/// `FrontendStrings`, `L10n`), so the gallery stays localized without preview-only keys.
enum WidgetPreviewSample {
    /// Server id carried by the sample items. It intentionally matches no real server — nothing in
    /// a gallery preview is interactive, and a fake id keeps sample items from being mistaken for
    /// something that resolves.
    static let serverId = "widget-preview"

    /// A representative mix of domains, ordered so the smaller families show the most recognisable
    /// ones first. Families that fit more tiles than this simply show fewer — repeating the same
    /// tile to fill a large widget reads worse than a shorter, honest sample.
    static let entities: [WidgetPreviewSampleEntity] = [
        entity(id: "light.preview", name: CoreStrings.componentLightTitle, domain: .light, state: .on),
        entity(id: "switch.preview", name: CoreStrings.componentSwitchTitle, domain: .switch, state: .off),
        entity(id: "cover.preview", name: CoreStrings.componentCoverTitle, domain: .cover, state: .open),
        entity(id: "fan.preview", name: CoreStrings.componentFanTitle, domain: .fan, state: .off),
        entity(id: "lock.preview", name: CoreStrings.componentLockTitle, domain: .lock, state: .locked),
        entity(id: "scene.preview", name: CoreStrings.componentSceneTitle, domain: .scene, state: nil),
        entity(
            id: "script.preview",
            name: CoreStrings.componentScriptTitle,
            domain: .script,
            state: nil,
            rawState: Domain.State.off.rawValue
        ),
        entity(
            id: "sensor.preview",
            name: L10n.Climate.Control.Temperature.title,
            domain: .sensor,
            state: nil,
            iconName: MaterialDesignIcons.thermometerIcon.name,
            stateValue: temperatureValue,
            rawState: "21.5"
        ),
    ]

    /// Sample sensor readings, in display order. Families with room for more tiles than this cycle
    /// through the list again — a repeated reading still reads as a grid of sensors, which is what
    /// the preview is there to show, where filler rows with no value look broken.
    static let sensorReadings: [(name: String, value: String, unit: String, icon: MaterialDesignIcons)] = [
        (L10n.Climate.Control.Temperature.title, "21.5", "°C", .thermometerIcon),
        (L10n.Climate.Control.Humidity.title, "45", "%", .waterPercentIcon),
        (FrontendStrings.panelEnergy, "12.4", "kWh", .lightningBoltIcon),
        (L10n.Watch.LightControls.power, "340", "W", .flashIcon),
    ]

    /// Sample frontend pages, using the panel titles the frontend table already translates.
    static let panels: [(title: String, path: String, component: String, icon: MaterialDesignIcons)] = [
        (FrontendStrings.panelStates, "lovelace", "lovelace", .viewDashboardIcon),
        (FrontendStrings.panelEnergy, "energy", "energy", .lightningBoltIcon),
        (FrontendStrings.panelHistory, "history", "history", .chartBoxIcon),
        (FrontendStrings.panelMap, "map", "map", .mapIcon),
        (FrontendStrings.panelMediaBrowser, "media-browser", "media_source", .playBoxMultipleIcon),
        (FrontendStrings.panelCalendar, "calendar", "calendar", .calendarIcon),
    ]

    /// Value shown by the sensor, details and gauge samples, so the previews agree with each other.
    static let temperatureValue = "21.5 °C"

    /// "Script 1", "Script 2"… — a translated noun plus a numeral, which needs no new string while
    /// still giving each sample tile a distinct label.
    static func numberedScriptName(index: Int) -> String {
        "\(CoreStrings.componentScriptTitle) \(index + 1)"
    }

    /// States keyed the way the tile widgets look them up, for the subset of sample items shown.
    static func entitiesState(for items: [MagicItem]) -> [MagicItem: WidgetEntityState] {
        let shown = Set(items)
        var states: [MagicItem: WidgetEntityState] = [:]
        for sample in entities where shown.contains(sample.magicItem) && !sample.state.value.isEmpty {
            states[sample.magicItem] = sample.state
        }
        return states
    }

    /// - Parameter rawState: the state the tile is colored from, for the samples whose displayed
    ///   value isn't one of the `Domain.State` cases (a sensor reading, a script's last run).
    private static func entity(
        id: String,
        name: String,
        domain: Domain,
        state: Domain.State?,
        iconName: String? = nil,
        stateValue: String? = nil,
        rawState: String? = nil
    ) -> WidgetPreviewSampleEntity {
        WidgetPreviewSampleEntity(
            magicItem: .init(id: id, serverId: serverId, type: .entity),
            info: .init(id: "\(serverId)-\(id)", name: name, iconName: iconName ?? domain.icon().name),
            state: .init(
                value: stateValue ?? state.map(stateName(for:)) ?? "",
                domainState: state,
                rawState: rawState ?? state?.rawValue ?? EntityStateActive.unknown,
                deviceClass: nil,
                liveColorHex: nil,
                groupMemberDomain: nil
            )
        )
    }

    private static func stateName(for state: Domain.State) -> String {
        switch state {
        case .on: return CoreStrings.commonStateOn
        case .off: return CoreStrings.commonStateOff
        case .open: return CoreStrings.commonStateOpen
        case .closed: return CoreStrings.commonStateClosed
        case .locked: return CoreStrings.commonStateLocked
        case .unlocked: return CoreStrings.commonStateUnlocked
        default: return ""
        }
    }
}
