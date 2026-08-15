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

    /// Empty-state copy shared by every layout, so the accessories draw the same distinction the
    /// home screen card does: an entry that was never set up says so, while one that is configured
    /// but came back without usable data — or failed to load — reports missing data instead.
    static func emptyStateText(isConfigured: Bool, loadFailed: Bool) -> String {
        isConfigured || loadFailed ? L10n.Widgets.Energy.noData : L10n.Widgets.Energy.notConfigured
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
