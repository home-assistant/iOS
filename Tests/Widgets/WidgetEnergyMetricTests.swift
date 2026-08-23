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
        // Net grid is -4.3 kWh (more returned than consumed), so both series point up.
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

    @available(iOS 17, *)
    @Test func placeholdersStandInForEverySeriesWhenThereIsNoData() {
        let entry = WidgetEnergyEntry(isConfigured: true)
        let metrics = WidgetEnergyMetric.metricsOrPlaceholders(for: entry)

        #expect(metrics.map(\.kind) == [.solar, .grid])
        #expect(metrics.allSatisfy { $0.value == WidgetEnergyStyle.emptyValue })
        #expect(metrics.allSatisfy { $0.unit == WidgetEnergyStyle.energyUnit })
        // Nothing to point at, so no arrows.
        #expect(metrics.allSatisfy { $0.direction == .none })
    }

    @available(iOS 17, *)
    @Test func placeholdersFollowTheSourcePreference() {
        let entry = WidgetEnergyEntry(source: .solar, isConfigured: true)
        #expect(WidgetEnergyMetric.metricsOrPlaceholders(for: entry).map(\.kind) == [.solar])
    }

    @available(iOS 17, *)
    @Test func realMetricsWinOverPlaceholders() {
        let entry = WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4)
        let metrics = WidgetEnergyMetric.metricsOrPlaceholders(for: entry)

        #expect(metrics.map(\.kind) == [.solar])
        #expect(metrics[0].value != WidgetEnergyStyle.emptyValue)
    }

    @available(iOS 17, *)
    @Test func totalsIgnoreLivePower() {
        let entry = WidgetEnergyEntry(
            isConfigured: true,
            gridConsumed: 6.2,
            gridReturned: 10.5,
            solarGenerated: 12.4,
            livePowerGrid: 250,
            livePowerSolar: 1450
        )
        let metrics = WidgetEnergyMetric.metrics(for: entry, figure: .totals)

        #expect(metrics.map(\.kind) == [.solar, .grid])
        #expect(metrics.allSatisfy { $0.unit == WidgetEnergyStyle.energyUnit })
    }

    /// The case the wide layouts hit on a home with solar but no grid statistics: the grid figure is
    /// dropped rather than shown as a blank beside a real solar total. Live grid power doesn't
    /// resurrect it — these layouts summarise the period.
    @available(iOS 17, *)
    @Test func totalsDropSeriesTheServerDoesNotReport() {
        let entry = WidgetEnergyEntry(isConfigured: true, solarGenerated: 40.3, livePowerGrid: 250)

        #expect(WidgetEnergyMetric.metrics(for: entry, figure: .totals).map(\.kind) == [.solar])
        #expect(WidgetEnergyMetric.metricsOrPlaceholders(for: entry, figure: .totals).map(\.kind) == [.solar])
    }

    @available(iOS 17, *)
    @Test func totalsStillStandInForEverySeriesWhenThereIsNoData() {
        let entry = WidgetEnergyEntry(isConfigured: true, livePowerGrid: 250, livePowerSolar: 1450)
        let metrics = WidgetEnergyMetric.metricsOrPlaceholders(for: entry, figure: .totals)

        #expect(metrics.map(\.kind) == [.solar, .grid])
        #expect(metrics.allSatisfy { $0.value == WidgetEnergyStyle.emptyValue })
    }
}
