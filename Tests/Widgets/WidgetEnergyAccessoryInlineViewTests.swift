@testable import HomeAssistant

import Shared
import Testing

@available(iOS 17, *)
struct WidgetEnergyAccessoryInlineViewTests {
    @Test func sharedUnitIsHoistedToTheEndOfTheLine() {
        let metrics: [WidgetEnergyMetric] = [
            .init(kind: .solar, value: "12.4", unit: "kWh", direction: .up),
            .init(kind: .grid, value: "6.2", unit: "kWh", direction: .down),
        ]
        #expect(WidgetEnergyAccessoryInlineView.text(for: metrics) == "\u{2191}12.4 \u{2193}6.2 kWh")
    }

    @Test func differingUnitsStayOnTheirOwnValue() {
        let metrics: [WidgetEnergyMetric] = [
            .init(kind: .solar, value: "1.4", unit: "kW", direction: .up),
            .init(kind: .grid, value: "250", unit: "W", direction: .down),
        ]
        #expect(WidgetEnergyAccessoryInlineView.text(for: metrics) == "\u{2191}1.4 kW \u{2193}250 W")
    }

    @Test func noMetricsFallsBackToTheEmptyStateText() {
        #expect(WidgetEnergyAccessoryInlineView.text(for: []) == L10n.Widgets.Energy.noData)
    }
}
