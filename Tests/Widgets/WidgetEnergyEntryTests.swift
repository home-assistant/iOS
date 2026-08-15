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
}
