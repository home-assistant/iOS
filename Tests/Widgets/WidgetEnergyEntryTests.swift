@testable import HomeAssistant

import Foundation
import Testing

struct WidgetEnergyEntryTests {
    @available(iOS 17, *)
    @Test func entryWithoutAnyStatisticsReportsNoData() {
        #expect(WidgetEnergyEntry(isConfigured: true).hasStatistics == false)
    }

    @available(iOS 17, *)
    @Test func anySingleTotalCountsAsData() {
        #expect(WidgetEnergyEntry(isConfigured: true, gridConsumed: 6.2).hasStatistics)
        #expect(WidgetEnergyEntry(isConfigured: true, gridReturned: 10.5).hasStatistics)
        #expect(WidgetEnergyEntry(isConfigured: true, solarGenerated: 12.4).hasStatistics)
        #expect(WidgetEnergyEntry(
            isConfigured: true,
            chartPoints: [.init(date: Date(timeIntervalSince1970: 0), grid: 0, solar: 0)]
        ).hasStatistics)
    }

    /// Live power describes right now, not the period, so it can't stand in for missing statistics —
    /// otherwise the early-morning fallback to yesterday would never fire on a server reporting power.
    @available(iOS 17, *)
    @Test func livePowerAloneIsNotPeriodData() {
        let entry = WidgetEnergyEntry(isConfigured: true, livePowerGrid: -180, livePowerSolar: 250)
        #expect(entry.hasStatistics == false)
    }

    /// The chart stacks the generation the home kept and draws the exported remainder below the
    /// axis, so the two must add back up to what was generated.
    @available(iOS 17, *)
    @Test func solarUsedIsGenerationMinusWhatWasExported() {
        let point = WidgetEnergyEntry.ChartPoint(
            date: Date(timeIntervalSince1970: 0),
            grid: 0.05,
            solar: 1.7,
            gridReturned: 0.97
        )
        #expect(abs(point.solarUsed - 0.73) < 0.0001)
    }

    /// Exporting more than was generated is possible with a battery discharging into the grid, or
    /// with meters that don't align bucket for bucket. Clamping keeps the bar from inverting.
    @available(iOS 17, *)
    @Test func solarUsedNeverGoesNegative() {
        let point = WidgetEnergyEntry.ChartPoint(
            date: Date(timeIntervalSince1970: 0),
            grid: 0,
            solar: 0.4,
            gridReturned: 1.2
        )
        #expect(point.solarUsed == 0)
    }

    /// A home that never exports is described by the two-series initialiser, which has to mean "no
    /// export" rather than leaving the new series undefined.
    @available(iOS 17, *)
    @Test func chartPointWithoutExportDefaultsToZero() {
        let point = WidgetEnergyEntry.ChartPoint(date: Date(timeIntervalSince1970: 0), grid: 0.4, solar: 0.2)
        #expect(point.gridReturned == 0)
        #expect(point.solarUsed == 0.2)
    }

    /// Net grid energy stays independent of the chart series: it's what the headline figure quotes.
    @available(iOS 17, *)
    @Test func gridNetIsReturnedMinusConsumed() {
        #expect(abs((WidgetEnergyEntry(gridConsumed: 6.2, gridReturned: 10.5).gridNet ?? 0) - 4.3) < 0.0001)
        #expect(WidgetEnergyEntry(gridConsumed: 6.2).gridNet == -6.2)
        #expect(WidgetEnergyEntry(solarGenerated: 12.4).gridNet == nil)
    }
}
