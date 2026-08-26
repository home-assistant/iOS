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

        var icon: MaterialDesignIcons {
            switch self {
            case .solar: .solarPowerIcon
            case .grid: .transmissionTowerIcon
            }
        }

        var label: String {
            switch self {
            case .solar: L10n.Widgets.Energy.solar
            case .grid: L10n.Widgets.Energy.grid
            }
        }

        /// Caption for the layouts wide enough to spell out what the figure covers. They summarise a
        /// whole period, so the grid figure is that period's electricity total rather than "Grid".
        var totalLabel: String {
            switch self {
            case .solar: L10n.Widgets.Energy.solar
            case .grid: L10n.Widgets.Energy.electricityTotal
            }
        }

        var color: Color {
            switch self {
            case .solar: WidgetEnergyStyle.solar
            case .grid: WidgetEnergyStyle.consumption
            }
        }

        /// SF Symbol stand-in for `icon`, used by the inline accessory where the system renders a
        /// single symbol next to the text and the Material Design font is unavailable.
        var accessorySymbol: SFSymbol {
            switch self {
            case .solar: .sunMaxFill
            case .grid: .boltFill
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

    /// The series the entry's source preference asks for, in headline order (solar first), skipping
    /// any the server doesn't report.
    static func metrics(
        for entry: WidgetEnergyEntry,
        figure: Figure = .livePowerOrTotals
    ) -> [WidgetEnergyMetric] {
        [
            entry.source.showsSolar ? solar(for: entry, figure: figure) : nil,
            entry.source.showsGrid ? grid(for: entry, figure: figure) : nil,
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
        return [
            entry.source.showsSolar ? placeholder(kind: .solar) : nil,
            entry.source.showsGrid ? placeholder(kind: .grid) : nil,
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
}

@available(iOS 17, *)
extension WidgetEnergyMetric {
    /// The drawing half of the metric, for the design system's energy components.
    ///
    /// `usesTotalLabel` picks the caption: the layouts wide enough to spell out what the figure
    /// covers say "Electricity total" where the compact ones just say "Grid".
    func designSystemModel(usesTotalLabel: Bool = false) -> WidgetEnergyStatModel {
        .init(
            id: id,
            icon: icon,
            value: value,
            unit: unit,
            label: usesTotalLabel ? kind.totalLabel : label,
            direction: direction,
            color: color,
            accessorySymbol: kind.accessorySymbol
        )
    }
}
