import Foundation
import SwiftUI
import UIKit

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

    enum Direction {
        case up, down, none

        var symbolName: String? {
            switch self {
            case .up: "arrow.up"
            case .down: "arrow.down"
            case .none: nil
            }
        }
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
