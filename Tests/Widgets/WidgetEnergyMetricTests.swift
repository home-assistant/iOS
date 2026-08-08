@testable import HomeAssistant

import Foundation
import Testing

struct WidgetEnergyMetricTests {
    @available(iOS 17, *)
    @Test func autoSourceUsesPeriodTotalsWhenNoLivePowerIsAvailable() {
        let entry = WidgetEnergyEntry(
            isConfigured: true,
            gridConsumed: 6.2,
            gridReturned: 10.5,
            solarGenerated: 12.4
        )
        let metrics = WidgetEnergyMetric.metrics(for: entry)

        #expect(metrics.map(\.kind) == [.solar, .grid])
        #expect(metrics.allSatisfy { $0.unit == WidgetEnergyStyle.energyUnit })
        // Net grid is +4.3 kWh (more returned than consumed), so both series point up.
        #expect(metrics.map(\.direction) == [.up, .up])
    }

    @available(iOS 17, *)
    @Test func livePowerIsPreferredOverPeriodTotals() {
        let entry = WidgetEnergyEntry(
            isConfigured: true,
            gridConsumed: 6.2,
            solarGenerated: 12.4,
            livePowerGrid: 250,
            livePowerSolar: 1450
        )
        let metrics = WidgetEnergyMetric.metrics(for: entry)

        #expect(metrics.map(\.kind) == [.solar, .grid])
        #expect(metrics[0].unit == UnitPower.kilowatts.symbol)
        #expect(metrics[1].unit == UnitPower.watts.symbol)
        // Positive live grid power means energy is being drawn from the grid.
        #expect(metrics[1].direction == .down)
    }

    @available(iOS 17, *)
    @Test func sourcePreferenceFiltersTheSeries() {
        let entry = WidgetEnergyEntry(
            source: .solar,
            isConfigured: true,
            gridConsumed: 6.2,
            solarGenerated: 12.4
        )
        #expect(WidgetEnergyMetric.metrics(for: entry).map(\.kind) == [.solar])

        var consumptionEntry = entry
        consumptionEntry.source = .consumption
        #expect(WidgetEnergyMetric.metrics(for: consumptionEntry).map(\.kind) == [.grid])
    }

    @available(iOS 17, *)
    @Test func seriesTheServerDoesNotReportAreDropped() {
        let solarOnly = WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4)
        #expect(WidgetEnergyMetric.metrics(for: solarOnly).map(\.kind) == [.solar])

        let nothing = WidgetEnergyEntry(isConfigured: true)
        #expect(WidgetEnergyMetric.metrics(for: nothing).isEmpty)
    }
}
