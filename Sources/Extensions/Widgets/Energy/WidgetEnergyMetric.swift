import SFSafeSymbols
import Shared
import SwiftUI

/// A single energy figure resolved from an entry, ready to render. Prefers live instantaneous power
/// (W) when power sensors are configured, otherwise falls back to the period's energy totals (kWh).
///
/// Shared by the compact layouts — the small card and the lock screen accessories — so they all
/// derive the same numbers from an entry.
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

    let kind: Kind
    let value: String
    let unit: String?
    let direction: WidgetEnergyStyle.Direction
    /// True when the figure is a stand-in for data the server hasn't reported yet.
    let isPlaceholder: Bool

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
    static func metrics(for entry: WidgetEnergyEntry) -> [WidgetEnergyMetric] {
        [
            entry.source.showsSolar ? solar(for: entry) : nil,
            entry.source.showsGrid ? grid(for: entry) : nil,
        ].compactMap { $0 }
    }

    /// The same series as `metrics(for:)`, but never empty: when the server has nothing to report for
    /// the period yet — early in the day, typically — the series the source preference asks for come
    /// back as blank stand-ins, so the layout keeps its shape instead of collapsing to a lone
    /// "no energy data" line.
    static func metricsOrPlaceholders(for entry: WidgetEnergyEntry) -> [WidgetEnergyMetric] {
        let metrics = metrics(for: entry)
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

    static func solar(for entry: WidgetEnergyEntry) -> WidgetEnergyMetric? {
        if let watts = entry.livePowerSolar {
            let power = WidgetEnergyStyle.power(watts)
            return .init(kind: .solar, value: power.value, unit: power.unit, direction: .up, isPlaceholder: false)
        }
        if let kWh = entry.solarGenerated {
            return .init(
                kind: .solar,
                value: WidgetEnergyStyle.energy(kWh),
                unit: WidgetEnergyStyle.energyUnit,
                direction: .up,
                isPlaceholder: false
            )
        }
        return nil
    }

    static func grid(for entry: WidgetEnergyEntry) -> WidgetEnergyMetric? {
        if let watts = entry.livePowerGrid {
            // Live grid power is net: positive is drawn from the grid, negative is returned to it.
            let power = WidgetEnergyStyle.power(watts)
            return .init(
                kind: .grid,
                value: power.value,
                unit: power.unit,
                direction: watts > 0 ? .down : .up,
                isPlaceholder: false
            )
        }
        if let net = entry.gridNet {
            return .init(
                kind: .grid,
                value: WidgetEnergyStyle.energy(net),
                unit: WidgetEnergyStyle.energyUnit,
                direction: net >= 0 ? .up : .down,
                isPlaceholder: false
            )
        }
        return nil
    }
}
