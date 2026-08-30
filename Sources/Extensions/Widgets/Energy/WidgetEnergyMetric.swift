import SFSafeSymbols
import Shared
import SwiftUI

/// A single energy figure resolved from an entry, ready to render. Prefers live instantaneous power
/// (W) when power sensors are configured, otherwise falls back to the period's energy totals (kWh).
///
/// Shared by every home screen and lock screen layout, so they all derive the same numbers from an
/// entry — and drop the same series when the server doesn't report one. The wide cards ask for
/// `Figure.totals`, which pins them to the period's energy regardless of live power.
@available(iOS 17, *)
struct WidgetEnergyMetric: Identifiable, Equatable {
    /// Which energy series the figure describes. Carries the presentation that never varies with
    /// the entry: icon, label and colour.
    enum Kind: String, CaseIterable {
        case solar
        case grid
        case battery
        case gas

        var icon: MaterialDesignIcons {
            switch self {
            case .solar: .solarPowerIcon
            case .grid: .transmissionTowerIcon
            case .battery: .batteryHighIcon
            case .gas: .fireIcon
            }
        }

        var label: String {
            switch self {
            case .solar: L10n.Widgets.Energy.solar
            case .grid: L10n.Widgets.Energy.grid
            case .battery: L10n.Widgets.Energy.battery
            case .gas: L10n.Widgets.Energy.gas
            }
        }

        /// Caption for the layouts wide enough to give a series its own wording. It reads the same
        /// as ``label`` in English today, and has its own keys so a translation can shorten the
        /// compact one without dragging the roomy one down with it.
        var expandedLabel: String {
            switch self {
            case .solar: L10n.Widgets.Energy.solar
            case .grid: L10n.Widgets.Energy.electricity
            case .battery: L10n.Widgets.Energy.battery
            case .gas: L10n.Widgets.Energy.gas
            }
        }

        var color: Color {
            switch self {
            case .solar: WidgetEnergyStyle.solar
            case .grid: WidgetEnergyStyle.consumption
            // The dashboard's battery total row is coloured by the discharge series, whichever way
            // the period's net went, so a battery that took more than it gave doesn't turn pink.
            case .battery: WidgetEnergyStyle.batteryOut
            case .gas: WidgetEnergyStyle.gas
            }
        }

        /// SF Symbol stand-in for `icon`, used by the inline accessory where the system renders a
        /// single symbol next to the text and the Material Design font is unavailable.
        var accessorySymbol: SFSymbol {
            switch self {
            case .solar: .sunMaxFill
            case .grid: .boltFill
            case .battery: .battery100percent
            case .gas: .flameFill
            }
        }
    }

    /// Which figure a metric reports. The wide layouts summarise a window, so they ask for the
    /// period's totals even when the entry also carries live power — the gallery placeholder does.
    enum Figure {
        /// Live instantaneous power (W) when power sensors report it, the period's totals otherwise.
        case livePowerOrTotals
        /// The period's energy totals (kWh), whatever live power the entry carries.
        case totals
    }

    let kind: Kind
    let value: String
    let unit: String?
    let direction: WidgetEnergyStyle.Direction
    /// True when the figure is a stand-in for data the server hasn't reported yet.
    let isPlaceholder: Bool

    /// Spelled out rather than left to the memberwise initialiser so `isPlaceholder` can stay
    /// immutable while every real metric keeps constructing without mentioning it.
    init(
        kind: Kind,
        value: String,
        unit: String?,
        direction: WidgetEnergyStyle.Direction,
        isPlaceholder: Bool = false
    ) {
        self.kind = kind
        self.value = value
        self.unit = unit
        self.direction = direction
        self.isPlaceholder = isPlaceholder
    }

    var id: String { kind.rawValue }
    var icon: MaterialDesignIcons { kind.icon }
    var label: String { kind.label }
    /// The series colour, except for a placeholder: a blank figure in solar orange or grid blue reads
    /// as content, so it stays in the secondary text colour instead.
    var color: Color { isPlaceholder ? WidgetEnergyStyle.secondaryText : kind.color }

    /// Value and unit on one line, e.g. "12,4 kWh", for the accessory layouts that can't stack them.
    var valueWithUnit: String {
        guard let unit else { return value }
        return "\(value) \(unit)"
    }

    /// The series the entry's source preference asks for, in headline order — grid, solar, battery,
    /// gas — skipping any the server doesn't report.
    ///
    /// The grid leads because it is the one series every energy dashboard has: a home may have no
    /// panels, no battery and no gas meter, but if the widget shows anything at all it shows this.
    /// It is also what the layouts with room for a single figure fall back to.
    static func metrics(
        for entry: WidgetEnergyEntry,
        figure: Figure = .livePowerOrTotals
    ) -> [WidgetEnergyMetric] {
        [
            entry.source.showsGrid ? grid(for: entry, figure: figure) : nil,
            entry.source.showsSolar ? solar(for: entry, figure: figure) : nil,
            entry.source.showsBattery ? battery(for: entry, figure: figure) : nil,
            entry.source.showsGas ? gas(for: entry) : nil,
        ].compactMap { $0 }
    }

    /// The same series as `metrics(for:)`, but never empty: when the server has nothing to report for
    /// the period yet — early in the day, typically — the series the source preference asks for come
    /// back as blank stand-ins, so the layout keeps its shape instead of collapsing. A series is only
    /// ever blanked alongside every other one: a stand-in next to a real figure would read as a
    /// broken series rather than as one this home doesn't have.
    static func metricsOrPlaceholders(
        for entry: WidgetEnergyEntry,
        figure: Figure = .livePowerOrTotals
    ) -> [WidgetEnergyMetric] {
        let metrics = metrics(for: entry, figure: figure)
        guard metrics.isEmpty else { return metrics }
        // Only the two headline series stand in. Blanking battery and gas as well would claim this
        // home has them, where solar and electricity are what any energy dashboard starts from.
        return [
            entry.source.showsGrid ? placeholder(kind: .grid) : nil,
            entry.source.showsSolar ? placeholder(kind: .solar) : nil,
        ].compactMap { $0 }
    }

    private static func placeholder(kind: Kind) -> WidgetEnergyMetric {
        .init(
            kind: kind,
            value: WidgetEnergyStyle.emptyValue,
            unit: WidgetEnergyStyle.energyUnit,
            direction: .none,
            isPlaceholder: true
        )
    }

    static func solar(for entry: WidgetEnergyEntry, figure: Figure = .livePowerOrTotals) -> WidgetEnergyMetric? {
        if figure == .livePowerOrTotals, let watts = entry.livePowerSolar {
            let power = WidgetEnergyStyle.power(watts)
            return .init(kind: .solar, value: power.value, unit: power.unit, direction: .up)
        }
        if let kWh = entry.solarGenerated {
            return .init(
                kind: .solar,
                value: WidgetEnergyStyle.energy(kWh),
                unit: WidgetEnergyStyle.energyUnit,
                direction: WidgetEnergyStyle.direction(ofTotal: kWh)
            )
        }
        return nil
    }

    static func grid(for entry: WidgetEnergyEntry, figure: Figure = .livePowerOrTotals) -> WidgetEnergyMetric? {
        if figure == .livePowerOrTotals, let watts = entry.livePowerGrid {
            // Live grid power is net: positive is drawn from the grid, negative is returned to it —
            // the same orientation as the period total below.
            let power = WidgetEnergyStyle.power(watts)
            return .init(
                kind: .grid,
                value: power.value,
                unit: power.unit,
                direction: WidgetEnergyStyle.gridDirection(ofTotal: watts)
            )
        }
        if let net = entry.gridNet {
            return .init(
                kind: .grid,
                value: WidgetEnergyStyle.energy(net),
                unit: WidgetEnergyStyle.energyUnit,
                direction: WidgetEnergyStyle.gridDirection(ofTotal: net)
            )
        }
        return nil
    }

    static func battery(for entry: WidgetEnergyEntry, figure: Figure = .livePowerOrTotals) -> WidgetEnergyMetric? {
        if figure == .livePowerOrTotals, let watts = entry.livePowerBattery {
            // Live battery power is net: positive is discharging into the home, negative is
            // charging — the same orientation as the period total below.
            let power = WidgetEnergyStyle.power(watts)
            return .init(
                kind: .battery,
                value: power.value,
                unit: power.unit,
                direction: WidgetEnergyStyle.direction(ofTotal: watts)
            )
        }
        if let net = entry.batteryNet {
            // Counted the way the dashboard's "Battery total" is: discharge positive, because a
            // battery is read as something that supplies the home rather than as a bill.
            return .init(
                kind: .battery,
                value: WidgetEnergyStyle.energy(net),
                unit: WidgetEnergyStyle.energyUnit,
                direction: WidgetEnergyStyle.direction(ofTotal: net)
            )
        }
        return nil
    }

    /// Gas takes no `figure`: a gas meter's live reading is a flow rate in m³/h, which is not a
    /// power, so there is no instantaneous figure for the compact layouts to prefer.
    static func gas(for entry: WidgetEnergyEntry) -> WidgetEnergyMetric? {
        guard let consumed = entry.gasConsumed else { return nil }
        return .init(
            kind: .gas,
            value: WidgetEnergyStyle.quantity(consumed),
            // Volume as often as energy, so the unit comes from the recorder rather than from here.
            unit: entry.gasUnit ?? WidgetEnergyStyle.energyUnit,
            direction: WidgetEnergyStyle.gridDirection(ofTotal: consumed)
        )
    }
}

@available(iOS 17, *)
extension WidgetEnergyMetric {
    /// The drawing half of the metric, for the design system's energy components.
    ///
    /// `usesExpandedLabel` picks the caption: the layouts with room for it get the series' own
    /// wording, the compact ones the short form.
    func designSystemModel(usesExpandedLabel: Bool = false) -> WidgetEnergyStatModel {
        .init(
            id: id,
            icon: icon,
            value: value,
            unit: unit,
            label: usesExpandedLabel ? kind.expandedLabel : label,
            direction: direction,
            color: color,
            accessorySymbol: kind.accessorySymbol
        )
    }
}
