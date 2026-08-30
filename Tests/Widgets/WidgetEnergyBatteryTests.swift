@testable import HomeAssistant

import Foundation
import Shared
import Testing

/// Covers the battery's place in the widget's arithmetic. A battery is the one source that both
/// takes and gives, so it is where the widget can most easily double-count: energy that charged the
/// battery was never demand, and energy the battery gave back was never bought. The allocation is a
/// port of `computeConsumptionSingle` in the frontend's `src/data/energy.ts`, and these pin it to
/// the priority order that function documents.
struct WidgetEnergyBatteryTests {
    private static let hourOne = Date(timeIntervalSince1970: 1_700_000_000)
    private static let hourTwo = Date(timeIntervalSince1970: 1_700_003_600)

    @available(iOS 17, *)
    private func point(
        grid: Double = 0,
        solar: Double = 0,
        gridReturned: Double = 0,
        batteryCharged: Double = 0,
        batteryDischarged: Double = 0
    ) -> WidgetEnergyEntry.ChartPoint {
        .init(
            date: Self.hourOne,
            grid: grid,
            solar: solar,
            gridReturned: gridReturned,
            batteryCharged: batteryCharged,
            batteryDischarged: batteryDischarged
        )
    }

    private func stats(_ byStatId: [String: [(Date, Double?)]]) -> EnergyStatistics {
        EnergyStatistics(byStatId: byStatId.mapValues { buckets in
            buckets.map { EnergyStatisticBucket(start: $0.0, change: $0.1) }
        })
    }

    private func isClose(_ lhs: Double, _ rhs: Double) -> Bool { abs(lhs - rhs) < 0.0001 }

    // MARK: - Allocation

    /// Charging from surplus generation is not consumption. 2 kWh generated with 1.5 stored leaves
    /// 0.5 the home actually used — stacking the full generation would put the bar at four times
    /// what the home demanded.
    @available(iOS 17, *)
    @Test func chargingFromSolarIsNotCountedAsConsumption() {
        let point = point(solar: 2.0, batteryCharged: 1.5)
        #expect(isClose(point.solarUsed, 0.5))
        #expect(isClose(point.gridUsed, 0))
        #expect(isClose(point.batteryUsed, 0))
    }

    /// Discharging into the home displaces the grid: the home used 1 kWh, all of it from the
    /// battery, and the grid bar stays empty rather than reporting the import that never happened.
    @available(iOS 17, *)
    @Test func dischargeCoversDemandBeforeTheGrid() {
        let point = point(batteryDischarged: 1.0)
        #expect(isClose(point.batteryUsed, 1.0))
        #expect(isClose(point.gridUsed, 0))
    }

    /// Solar covers demand before the battery does, and the battery before the grid — the order the
    /// dashboard applies. 1 kWh of solar and 1 kWh of discharge against 2.5 kWh of demand leaves
    /// exactly the shortfall on the grid.
    @available(iOS 17, *)
    @Test func demandIsCoveredInTheDashboardsPriorityOrder() {
        let point = point(grid: 0.5, solar: 1.0, batteryDischarged: 1.0)
        #expect(isClose(point.solarUsed, 1.0))
        #expect(isClose(point.batteryUsed, 1.0))
        #expect(isClose(point.gridUsed, 0.5))
    }

    /// Grid import beyond what the home consumed can only have gone into the battery, and has to be
    /// claimed before solar fills it — otherwise that import is stranded and the split stops adding
    /// up. Here 2 kWh is imported and 0.5 kWh generated while the battery takes 1.5 kWh: 1 kWh of
    /// the import is attributed to charging, and the generation fills the rest of the battery.
    ///
    /// Which leaves the home's own 1 kWh of demand entirely on the grid, and nothing on solar. That
    /// reads backwards until you follow the dashboard's priority order — Solar → Battery comes
    /// before Solar → Consumption — so generation that went into the battery was never consumption,
    /// however much the home drew at the same moment.
    @available(iOS 17, *)
    @Test func gridImportBeyondDemandIsAttributedToCharging() {
        let point = point(grid: 2.0, solar: 0.5, batteryCharged: 1.5)
        #expect(isClose(point.gridUsed, 1.0))
        #expect(isClose(point.solarUsed, 0))
        #expect(isClose(point.batteryUsed, 0))
    }

    /// A battery that only ever moved energy in and back out again leaves nothing on the chart:
    /// nothing was generated, imported or demanded.
    @available(iOS 17, *)
    @Test func aBucketThatOnlyCyclesTheBatteryPlotsNothing() {
        let point = point(batteryCharged: 1.0, batteryDischarged: 1.0)
        #expect(isClose(point.solarUsed, 0))
        #expect(isClose(point.gridUsed, 0))
        #expect(isClose(point.batteryUsed, 0))
    }

    /// The three used shares are what the chart stacks, so together they must equal what the home
    /// actually consumed — everything that came in, less everything that left.
    @available(iOS 17, *)
    @Test func usedSharesAddUpToWhatTheHomeConsumed() {
        let point = point(
            grid: 1.2,
            solar: 2.4,
            gridReturned: 0.8,
            batteryCharged: 0.6,
            batteryDischarged: 0.3
        )
        let used = point.solarUsed + point.gridUsed + point.batteryUsed
        #expect(isClose(used, 1.2 + 2.4 + 0.3 - 0.8 - 0.6))
    }

    /// Adding a battery with no traffic must not move a single existing bar: every home without one
    /// keeps the split it had before the series existed.
    @available(iOS 17, *)
    @Test func anIdleBatteryLeavesTheOriginalSplitUntouched() {
        let withBattery = point(grid: 0.05, solar: 1.7, gridReturned: 0.97)
        #expect(isClose(withBattery.solarUsed, 0.73))
        #expect(isClose(withBattery.gridUsed, 0.05))
    }

    // MARK: - Totals

    /// The battery total is oriented the way the dashboard's is — discharge positive — which is the
    /// opposite of the grid's. Getting it backwards would report a charging battery as a supply.
    @available(iOS 17, *)
    @Test func batteryNetIsDischargeMinusCharge() {
        let entry = WidgetEnergyEntry(isConfigured: true, batteryCharged: 4.0, batteryDischarged: 2.5)
        #expect(entry.batteryNet == -1.5)
    }

    /// A dashboard with no battery has no total to show, which is distinct from a battery that
    /// broke even.
    @available(iOS 17, *)
    @Test func noBatteryStatisticsMeansNoTotal() {
        #expect(WidgetEnergyEntry(isConfigured: true, gridConsumed: 6.2).batteryNet == nil)
    }

    /// Battery statistics alone are enough to say the period had data, so the early-morning
    /// fallback doesn't fire on a home whose battery is the only thing reporting.
    @available(iOS 17, *)
    @Test func batteryTotalsCountAsPeriodData() {
        #expect(WidgetEnergyEntry(isConfigured: true, batteryDischarged: 2.5).hasStatistics)
        #expect(WidgetEnergyEntry(isConfigured: true, batteryCharged: 4.0).hasStatistics)
    }

    // MARK: - Aggregation

    /// A battery's `stat_energy_from` is what it gave back and `stat_energy_to` what it took — the
    /// opposite way round to a grid source. Swapping them would draw every charge as a discharge.
    @available(iOS 17, *)
    @Test func chargeAndDischargeReachTheChartInTheRightDirection() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: ["grid_import"],
            exportIds: [],
            solarIds: ["solar"],
            batteryChargeIds: ["battery_to"],
            batteryDischargeIds: ["battery_from"],
            in: stats([
                "grid_import": [(Self.hourOne, 0.4), (Self.hourTwo, 0.1)],
                "solar": [(Self.hourOne, 2.0), (Self.hourTwo, 0)],
                "battery_to": [(Self.hourOne, 1.5), (Self.hourTwo, 0)],
                "battery_from": [(Self.hourOne, 0), (Self.hourTwo, 0.8)],
            ])
        )
        #expect(points.map(\.batteryCharged) == [1.5, 0])
        #expect(points.map(\.batteryDischarged) == [0, 0.8])
    }

    /// A bucket only the battery reported still has to appear, or the chart drops the hour where an
    /// off-grid evening ran entirely on stored energy.
    @available(iOS 17, *)
    @Test func aBucketOnlyTheBatteryReportedStillAppears() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: ["grid_import"],
            exportIds: [],
            solarIds: [],
            batteryChargeIds: [],
            batteryDischargeIds: ["battery_from"],
            in: stats([
                "grid_import": [(Self.hourOne, 0.4)],
                "battery_from": [(Self.hourTwo, 0.8)],
            ])
        )
        #expect(points.map(\.date) == [Self.hourOne, Self.hourTwo])
        #expect(points.map(\.batteryDischarged) == [0, 0.8])
    }

    /// Homes with more than one battery are summed into one series, the way multiple grid meters
    /// already are.
    @available(iOS 17, *)
    @Test func severalBatteriesAreSummedIntoOneSeries() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: [],
            exportIds: [],
            solarIds: [],
            batteryChargeIds: ["battery_1_to", "battery_2_to"],
            batteryDischargeIds: ["battery_1_from", "battery_2_from"],
            in: stats([
                "battery_1_to": [(Self.hourOne, 0.5)],
                "battery_2_to": [(Self.hourOne, 0.25)],
                "battery_1_from": [(Self.hourOne, 0.1)],
                "battery_2_from": [(Self.hourOne, 0.2)],
            ])
        )
        #expect(points.count == 1)
        #expect(isClose(points[0].batteryCharged, 0.75))
        #expect(isClose(points[0].batteryDischarged, 0.3))
    }

    // MARK: - Metric

    /// The figure follows the dashboard's "Battery total": a net discharge points up, because a
    /// battery is read as something that supplies the home rather than as a bill.
    @available(iOS 17, *)
    @Test func netDischargePointsUp() {
        let entry = WidgetEnergyEntry(isConfigured: true, batteryCharged: 1.0, batteryDischarged: 3.5)
        let metric = WidgetEnergyMetric.battery(for: entry, figure: .totals)
        #expect(metric?.direction == .up)
        #expect(metric?.unit == WidgetEnergyStyle.energyUnit)
    }

    @available(iOS 17, *)
    @Test func netChargePointsDown() {
        let entry = WidgetEnergyEntry(isConfigured: true, batteryCharged: 3.5, batteryDischarged: 1.0)
        #expect(WidgetEnergyMetric.battery(for: entry, figure: .totals)?.direction == .down)
    }

    /// Live battery power is preferred over the period total on the compact layouts, and is signed
    /// the same way: positive is discharging into the home.
    @available(iOS 17, *)
    @Test func liveBatteryPowerIsPreferredWhenReported() {
        let entry = WidgetEnergyEntry(
            isConfigured: true,
            batteryCharged: 3.5,
            batteryDischarged: 1.0,
            livePowerBattery: 1450
        )
        let metric = WidgetEnergyMetric.battery(for: entry)
        #expect(metric?.direction == .up)
        #expect(metric?.unit == UnitPower.kilowatts.symbol)
    }

    /// A home with no battery drops the series rather than showing a blank one beside real figures.
    @available(iOS 17, *)
    @Test func noBatteryMeansNoMetric() {
        let entry = WidgetEnergyEntry(isConfigured: true, gridConsumed: 6.2)
        #expect(WidgetEnergyMetric.battery(for: entry) == nil)
        #expect(WidgetEnergyMetric.metrics(for: entry).map(\.kind) == [.grid])
    }

    /// Narrowing the widget to one source drops every other series, battery included.
    @available(iOS 17, *)
    @Test func theSourcePreferenceSelectsWhichSeriesAppear() {
        let entry = WidgetEnergyEntry(
            source: .battery,
            isConfigured: true,
            gridConsumed: 6.2,
            solarGenerated: 12.4,
            batteryDischarged: 2.5,
            gasConsumed: 4.8,
            gasUnit: "m³"
        )
        #expect(WidgetEnergyMetric.metrics(for: entry, figure: .totals).map(\.kind) == [.battery])
    }
}
