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
        // Nothing went back, so every kWh that came in was demand.
        #expect(point.gridUsed == 0.4)
    }

    /// Net grid energy stays independent of the chart series: it's what the headline figure quotes.
    /// Oriented like the dashboard's "Electricity total" — drawn from the grid counts positive, so a
    /// home that returned more than it took ends the period below zero.
    @available(iOS 17, *)
    @Test func gridNetIsConsumedMinusReturned() {
        #expect(abs((WidgetEnergyEntry(gridConsumed: 6.2, gridReturned: 10.5).gridNet ?? 0) + 4.3) < 0.0001)
        #expect(WidgetEnergyEntry(gridConsumed: 6.2).gridNet == 6.2)
        #expect(WidgetEnergyEntry(solarGenerated: 12.4).gridNet == nil)
    }

    /// A bucket that both imported and exported only demanded the difference. The dashboard's graph
    /// plots that difference, so the import share has to come down to meet it — the widget used to
    /// plot the raw import and stood the bar above anything the home consumed.
    @available(iOS 17, *)
    @Test func gridUsedExcludesImportThatLeftAgain() {
        let point = WidgetEnergyEntry.ChartPoint(
            date: Date(timeIntervalSince1970: 0),
            grid: 5,
            solar: 0,
            gridReturned: 3
        )
        #expect(point.gridUsed == 2)
        #expect(point.solarUsed == 0)
    }

    /// Generation covers the export before it covers the home, and the grid covers only what is
    /// left. The two used shares add up to everything the home consumed that bucket.
    @available(iOS 17, *)
    @Test func generationCoversTheExportBeforeTheHome() {
        let point = WidgetEnergyEntry.ChartPoint(
            date: Date(timeIntervalSince1970: 0),
            grid: 1,
            solar: 2,
            gridReturned: 1.5
        )
        #expect(abs(point.solarUsed - 0.5) < 0.0001)
        #expect(abs(point.gridUsed - 1) < 0.0001)
    }

    /// Exporting more than everything that came in leaves nothing to have been used, rather than a
    /// bar that dips below the axis on the consumption side.
    @available(iOS 17, *)
    @Test func aBucketThatExportedEverythingUsedNothing() {
        let point = WidgetEnergyEntry.ChartPoint(
            date: Date(timeIntervalSince1970: 0),
            grid: 1,
            solar: 0.5,
            gridReturned: 2
        )
        #expect(point.gridUsed == 0)
        #expect(point.solarUsed == 0)
    }
}
