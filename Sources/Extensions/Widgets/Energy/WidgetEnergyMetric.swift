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

    var id: String { kind.rawValue }
    var icon: MaterialDesignIcons { kind.icon }
    var label: String { kind.label }
    var color: Color { kind.color }

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

    static func solar(for entry: WidgetEnergyEntry) -> WidgetEnergyMetric? {
        if let watts = entry.livePowerSolar {
            let power = WidgetEnergyStyle.power(watts)
            return .init(kind: .solar, value: power.value, unit: power.unit, direction: .up)
        }
        if let kWh = entry.solarGenerated {
            return .init(
                kind: .solar,
                value: WidgetEnergyStyle.energy(kWh),
                unit: WidgetEnergyStyle.energyUnit,
                direction: .up
            )
        }
        return nil
    }

    static func grid(for entry: WidgetEnergyEntry) -> WidgetEnergyMetric? {
        if let watts = entry.livePowerGrid {
            // Live grid power is net: positive is drawn from the grid, negative is returned to it.
            let power = WidgetEnergyStyle.power(watts)
            return .init(kind: .grid, value: power.value, unit: power.unit, direction: watts > 0 ? .down : .up)
        }
        if let net = entry.gridNet {
            return .init(
                kind: .grid,
                value: WidgetEnergyStyle.energy(net),
                unit: WidgetEnergyStyle.energyUnit,
                direction: net >= 0 ? .up : .down
            )
        }
        return nil
    }
}
