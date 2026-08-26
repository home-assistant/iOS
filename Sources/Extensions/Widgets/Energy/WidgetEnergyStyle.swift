import Foundation
import Shared
import SwiftUI
import WidgetKit

/// Colours and value formatting shared across the Energy widget views.
///
/// The values themselves live in the design system's `WidgetEnergyPalette`, so the gallery draws the
/// same card the widget does. What stays here is the part that needs the app: the entry-aware empty
/// state, which is where "not configured" and "no data" are told apart.
enum WidgetEnergyStyle {
    typealias Direction = WidgetEnergyDirection

    static let background = WidgetEnergyPalette.background
    static let primaryText = WidgetEnergyPalette.primaryText
    static let secondaryText = WidgetEnergyPalette.secondaryText

    /// Solar generation. Matches the frontend `--energy-solar-color` (#ff9800).
    static let solar = WidgetEnergyPalette.solar
    /// Energy consumed from the grid. Matches the frontend `--energy-grid-consumption-color` (#488fc2).
    static let consumption = WidgetEnergyPalette.consumption
    /// Energy returned to the grid. Matches the frontend `--energy-grid-return-color` (#8353d1).
    static let gridReturn = WidgetEnergyPalette.gridReturn

    /// Unit symbol for energy, sourced from Foundation rather than hardcoded.
    static let energyUnit = WidgetEnergyPalette.energyUnit

    /// Stand-in for a figure the server hasn't reported yet — early in the day the statistics simply
    /// have no buckets. Keeps the layout intact without claiming the value is zero.
    static let emptyValue = WidgetEnergyPalette.emptyValue

    /// Arrow describing a signed energy total: up when generating or exporting, down when consuming,
    /// and no arrow at all when there is no total to describe.
    static func direction(ofTotal value: Double?) -> Direction {
        WidgetEnergyPalette.direction(ofTotal: value)
    }

    /// Arrow describing a grid figure, which counts energy drawn from the grid as positive the way
    /// the energy dashboard's "Electricity total" does.
    static func gridDirection(ofTotal value: Double?) -> Direction {
        WidgetEnergyPalette.gridDirection(ofTotal: value)
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
    /// colours to luminance. Only use the series colour when the widget renders in full colour.
    static func accessoryColor(_ color: Color, mode: WidgetRenderingMode) -> Color {
        WidgetEnergyPalette.accessoryColor(color, mode: mode)
    }

    /// Formats an energy value in kWh (locale-aware, at most one fraction digit).
    static func energy(_ kWh: Double) -> String {
        WidgetEnergyPalette.energy(kWh)
    }

    /// Formats an instantaneous power magnitude, scaling W → kW → MW like the dashboard.
    static func power(_ watts: Double) -> (value: String, unit: String) {
        WidgetEnergyPalette.power(watts)
    }

    /// Formats a monetary amount using the server's currency when known.
    static func cost(_ value: Double, code: String?) -> String {
        WidgetEnergyPalette.cost(value, code: code)
    }
}
