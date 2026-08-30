@testable import HomeAssistant

import Shared
import Testing

struct WidgetEnergyAccessoryInlineViewTests {
    @available(iOS 17, *)
    @Test func sharedUnitIsHoistedToTheEndOfTheLine() {
        let metrics: [WidgetEnergyMetric] = [
            .init(kind: .solar, value: "12.4", unit: "kWh", direction: .up),
            .init(kind: .grid, value: "6.2", unit: "kWh", direction: .down),
        ]
        #expect(WidgetEnergyAccessoryInlineView.text(for: metrics) == "\u{2191}12.4 \u{2193}6.2 kWh")
    }

    @available(iOS 17, *)
    @Test func differingUnitsStayOnTheirOwnValue() {
        let metrics: [WidgetEnergyMetric] = [
            .init(kind: .solar, value: "1.4", unit: "kW", direction: .up),
            .init(kind: .grid, value: "250", unit: "W", direction: .down),
        ]
        #expect(WidgetEnergyAccessoryInlineView.text(for: metrics) == "\u{2191}1.4 kW \u{2193}250 W")
    }

    @available(iOS 17, *)
    @Test func noMetricsJoinsToNothingSoTheViewCanPickTheEmptyState() {
        #expect(WidgetEnergyAccessoryInlineView.text(for: []).isEmpty)
    }

    @available(iOS 17, *)
    @Test func emptyStateDistinguishesUnconfiguredFromMissingData() {
        #expect(
            WidgetEnergyStyle.emptyStateText(for: WidgetEnergyEntry(isConfigured: false))
                == L10n.Widgets.Energy.notConfigured
        )
        // A load failure against a server we never confirmed has an energy dashboard is still a
        // data problem, not a setup problem.
        #expect(
            WidgetEnergyStyle.emptyStateText(for: WidgetEnergyEntry(isConfigured: false, loadFailed: true))
                == L10n.Widgets.Energy.noData
        )
        #expect(
            WidgetEnergyStyle.emptyStateText(for: WidgetEnergyEntry(isConfigured: true))
                == L10n.Widgets.Energy.noData
        )
    }

    /// No active URL is neither a missing dashboard nor missing data: the app has nowhere to load
    /// from, so the copy points at the URL configuration instead.
    @available(iOS 17, *)
    @Test func emptyStateReportsMissingConnectionAheadOfEverythingElse() {
        #expect(
            WidgetEnergyStyle.emptyStateText(for: WidgetEnergyEntry(isConfigured: false, noConnection: true))
                == L10n.Widgets.Energy.noConnection
        )
        // Even when a load was also flagged as failed, the connection is the actionable problem.
        #expect(
            WidgetEnergyStyle.emptyStateText(
                for: WidgetEnergyEntry(isConfigured: false, loadFailed: true, noConnection: true)
            ) == L10n.Widgets.Energy.noConnection
        )
    }
}
