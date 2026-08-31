#if !os(watchOS)
import Foundation
import SwiftUI
import WidgetKit

/// Colours and value formatting shared across the Energy widget views. Colours adapt to light/dark.
public enum WidgetEnergyPalette {
    public static let background = Color(uiColor: .systemBackground)
    public static let primaryText = Color(uiColor: .label)
    public static let secondaryText = Color(uiColor: .secondaryLabel)

    /// Solar generation. Matches the frontend `--energy-solar-color` (#ff9800).
    public static let solar = Color(red: 1.0, green: 0.596, blue: 0.0)
    /// Energy consumed from the grid. Matches the frontend `--energy-grid-consumption-color` (#488fc2).
    public static let consumption = Color(red: 0.282, green: 0.561, blue: 0.761)
    /// Energy returned to the grid. Matches the frontend `--energy-grid-return-color` (#8353d1).
    public static let gridReturn = Color(red: 0.514, green: 0.325, blue: 0.820)
    /// Energy the battery gave back. Matches the frontend `--energy-battery-out-color` (#4db6ac).
    public static let batteryOut = Color(red: 0.302, green: 0.714, blue: 0.675)
    /// Energy that went into the battery. Matches the frontend `--energy-battery-in-color` (#f06292).
    public static let batteryIn = Color(red: 0.941, green: 0.384, blue: 0.573)
    /// Gas consumption. The frontend's `--energy-gas-color` (#8e021b) is a near-black red that only
    /// ever sits on a light dashboard; the widget draws it as label-sized text on either appearance,
    /// so dark mode gets a lightened variant rather than a figure that disappears into the card.
    public static let gas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.902, green: 0.318, blue: 0.376, alpha: 1)
            : UIColor(red: 0.557, green: 0.008, blue: 0.106, alpha: 1)
    })

    /// Unit symbol for energy, sourced from Foundation rather than hardcoded.
    public static let energyUnit = UnitEnergy.kilowattHours.symbol

    /// Stand-in for a figure the server hasn't reported yet — early in the day the statistics simply
    /// have no buckets. Keeps the layout intact without claiming the value is zero.
    public static let emptyValue = "—"

    /// Lock screen accessories render vibrant or accented, where the system flattens saturated
    /// colours to luminance — solar orange and grid blue would end up as two indistinguishable
    /// greys. Only use the series colour when the widget renders in full colour (StandBy, previews).
    public static func accessoryColor(_ color: Color, mode: WidgetRenderingMode) -> Color {
        mode == .fullColor ? color : .primary
    }

    /// Formats a bare quantity (locale-aware, at most one fraction digit). Gas is metered in m³ or
    /// in kWh depending on the source, so its number is formatted the same way but carries a unit
    /// the entry supplies rather than the kWh one.
    public static func quantity(_ value: Double) -> String {
        abs(value).formatted(.number.precision(.fractionLength(abs(value) >= 100 ? 0 : 1)))
    }

    /// Formats an energy value in kWh (locale-aware, at most one fraction digit).
    public static func energy(_ kWh: Double) -> String {
        quantity(kWh)
    }

    /// Formats an instantaneous power magnitude, scaling W → kW → MW like the dashboard. The unit
    /// symbol is taken from Foundation's `UnitPower` so it stays locale-correct.
    public static func power(_ watts: Double) -> (value: String, unit: String) {
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
    public static func cost(_ value: Double, code: String?) -> String {
        if let code {
            return value.formatted(.currency(code: code))
        }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    /// Arrow describing a signed energy total: up when generating or exporting, down when consuming,
    /// and no arrow at all when there is no total to describe.
    public static func direction(ofTotal value: Double?) -> WidgetEnergyDirection {
        guard let value else { return .none }
        return value >= 0 ? .up : .down
    }

    /// Arrow describing a grid figure, which counts energy drawn from the grid as positive the way
    /// the energy dashboard's "Electricity total" does. That is the opposite orientation to a
    /// generation figure, so the arrow runs the other way: drawing points down, sending back points
    /// up, and a period that broke even points up rather than nowhere.
    public static func gridDirection(ofTotal value: Double?) -> WidgetEnergyDirection {
        guard let value else { return .none }
        return value > 0 ? .down : .up
    }
}
#endif
