import Foundation
import SFSafeSymbols
import Shared
import SwiftUI
import UIKit
import WidgetKit

/// Colours and value formatting shared across the Energy widget views. Colours adapt to light/dark.
enum WidgetEnergyStyle {
    static let background = Color(uiColor: .systemBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)

    /// Solar generation. Matches the frontend `--energy-solar-color` (#ff9800).
    static let solar = Color(red: 1.0, green: 0.596, blue: 0.0)
    /// Energy consumed from the grid. Matches the frontend `--energy-grid-consumption-color` (#488fc2).
    static let consumption = Color(red: 0.282, green: 0.561, blue: 0.761)
    /// Energy returned to the grid. Matches the frontend `--energy-grid-return-color` (#8353d1).
    static let gridReturn = Color(red: 0.514, green: 0.325, blue: 0.820)

    /// Unit symbol for energy, sourced from Foundation rather than hardcoded.
    static let energyUnit = UnitEnergy.kilowattHours.symbol

    /// Stand-in for a figure the server hasn't reported yet — early in the day the statistics simply
    /// have no buckets. Keeps the layout intact without claiming the value is zero.
    static let emptyValue = "—"

    enum Direction {
        case up, down, none

        var symbol: SFSymbol? {
            switch self {
            case .up: .arrowUp
            case .down: .arrowDown
            case .none: nil
            }
        }

        /// Text-only arrow, for the inline accessory where the system allows a single leading symbol
        /// and the direction has to travel inside the text itself.
        var arrowCharacter: String {
            switch self {
            case .up: "\u{2191}"
            case .down: "\u{2193}"
            case .none: ""
            }
        }
    }

    /// Arrow describing a signed energy total: up when generating or exporting, down when consuming,
    /// and no arrow at all when there is no total to describe.
    static func direction(ofTotal value: Double?) -> Direction {
        guard let value else { return .none }
        return value >= 0 ? .up : .down
    }

    /// Arrow describing a grid figure, which counts energy drawn from the grid as positive the way
    /// the energy dashboard's "Electricity total" does. That is the opposite orientation to a
    /// generation figure, so the arrow runs the other way: drawing points down, sending back points
    /// up, and a period that broke even points up rather than nowhere.
    static func gridDirection(ofTotal value: Double?) -> Direction {
        guard let value else { return .none }
        return value > 0 ? .down : .up
    }

    /// Empty-state copy shared by every layout, so the accessories draw the same distinction the
    /// home screen card does: a server the app has no URL to reach points at the URL configuration,
    /// an entry that was never set up says so, and one that is configured but came back without
    /// usable data — or failed to load — reports missing data instead.
    @available(iOS 17, *)
    static func emptyStateText(for entry: WidgetEnergyEntry) -> String {
        if entry.noConnection {
            return L10n.Widgets.Energy.noConnection
        }
        return entry.isConfigured || entry.loadFailed ? L10n.Widgets.Energy.noData : L10n.Widgets.Energy.notConfigured
    }

    /// Lock screen accessories render vibrant or accented, where the system flattens saturated
    /// colours to luminance — solar orange and grid blue would end up as two indistinguishable
    /// greys. Only use the series colour when the widget renders in full colour (StandBy, previews).
    static func accessoryColor(_ color: Color, mode: WidgetRenderingMode) -> Color {
        mode == .fullColor ? color : .primary
    }

    /// Formats an energy value in kWh (locale-aware, at most one fraction digit).
    static func energy(_ kWh: Double) -> String {
        abs(kWh).formatted(.number.precision(.fractionLength(abs(kWh) >= 100 ? 0 : 1)))
    }

    /// Formats an instantaneous power magnitude, scaling W → kW → MW like the dashboard. The unit
    /// symbol is taken from Foundation's `UnitPower` so it stays locale-correct.
    static func power(_ watts: Double) -> (value: String, unit: String) {
        let magnitude = abs(watts)
        if magnitude >= 1_000_000 {
            let value = (watts / 1_000_000).magnitude.formatted(.number.precision(.fractionLength(1)))
            return (value, UnitPower.megawatts.symbol)
        }
        if magnitude >= 1000 {
            let value = (watts / 1000).magnitude.formatted(.number.precision(.fractionLength(1)))
            return (value, UnitPower.kilowatts.symbol)
        }
        return (Int(magnitude.rounded()).formatted(), UnitPower.watts.symbol)
    }

    /// Formats a monetary amount using the server's currency when known.
    static func cost(_ value: Double, code: String?) -> String {
        if let code {
            return value.formatted(.currency(code: code))
        }
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}
