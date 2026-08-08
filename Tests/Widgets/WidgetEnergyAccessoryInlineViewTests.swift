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

    @Test func emptyStateDistinguishesUnconfiguredFromMissingData() {
        #expect(
            WidgetEnergyStyle.emptyStateText(isConfigured: false, loadFailed: false)
                == L10n.Widgets.Energy.notConfigured
        )
        // A load failure against a server we never confirmed has an energy dashboard is still a
        // data problem, not a setup problem.
        #expect(WidgetEnergyStyle.emptyStateText(isConfigured: false, loadFailed: true) == L10n.Widgets.Energy.noData)
        #expect(WidgetEnergyStyle.emptyStateText(isConfigured: true, loadFailed: false) == L10n.Widgets.Energy.noData)
    }
}
