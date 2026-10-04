@testable import HomeAssistant

import Foundation
import Testing

/// The sample day the energy widget's gallery card and previews draw: its series have to be
/// consistent with one another the way a real home's are, and its totals have to add up to it.
struct WidgetEnergyChartSampleTests {
    private static let dayStart = Date(timeIntervalSince1970: 1_700_000_000)

    @available(iOS 17, *)
    @Test func sampleDayIsTwentyFourHourlyBuckets() {
        let points = WidgetEnergyChartSample.day(startingAt: Self.dayStart)

        #expect(points.count == 24)
        #expect(points.first?.date == Self.dayStart)
        #expect(points.last?.date == Self.dayStart.addingTimeInterval(23 * 3600))
        // No sun at night, and the home both draws and returns energy at some point in the day.
        #expect(points[0].solar == 0)
        #expect(points[12].solar > 0)
        #expect(points.contains { $0.gridReturned > 0 })
        #expect(points.allSatisfy { $0.grid >= 0 && $0.gridReturned >= 0 })
        // Energy is never both drawn and returned in the same hour.
        #expect(points.allSatisfy { $0.grid == 0 || $0.gridReturned == 0 })
        #expect(points.allSatisfy { $0.batteryCharged == 0 && $0.batteryDischarged == 0 })
    }

    @available(iOS 17, *)
    @Test func batteryDayStoresTheSurplusAndCoversTheEveningPeak() {
        let plain = WidgetEnergyChartSample.day(startingAt: Self.dayStart)
        let battery = WidgetEnergyChartSample.dayWithBattery(startingAt: Self.dayStart)

        #expect(battery.count == 24)
        #expect(battery.contains { $0.batteryCharged > 0 })
        #expect(battery.contains { $0.batteryDischarged > 0 })
        for (withBattery, without) in zip(battery, plain) {
            #expect(withBattery.solar == without.solar)
            #expect(withBattery.grid <= without.grid)
            #expect(withBattery.gridReturned <= without.gridReturned)
            #expect(withBattery.batteryCharged <= without.gridReturned)
        }
    }

    @available(iOS 17, *)
    @Test func totalsAddUpTheSeries() {
        let points = WidgetEnergyChartSample.dayWithBattery(startingAt: Self.dayStart)

        let totals = WidgetEnergyChartSample.totals(of: points)

        #expect(abs(totals.gridConsumed - points.map(\.grid).reduce(0, +)) < 0.000_1)
        #expect(abs(totals.gridReturned - points.map(\.gridReturned).reduce(0, +)) < 0.000_1)
        #expect(abs(totals.solarGenerated - points.map(\.solar).reduce(0, +)) < 0.000_1)
        #expect(abs(totals.batteryCharged - points.map(\.batteryCharged).reduce(0, +)) < 0.000_1)
        #expect(abs(totals.batteryDischarged - points.map(\.batteryDischarged).reduce(0, +)) < 0.000_1)
        #expect(totals.batteryCharged > 0)
    }

    @available(iOS 17, *)
    @Test func totalsOfNothingAreZero() {
        let totals = WidgetEnergyChartSample.totals(of: [])

        #expect(totals.gridConsumed == 0)
        #expect(totals.solarGenerated == 0)
        #expect(totals.batteryDischarged == 0)
    }
}
