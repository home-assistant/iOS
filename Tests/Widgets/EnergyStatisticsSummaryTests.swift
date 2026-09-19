import Foundation
import Shared
import Testing

/// The aggregation both energy summaries are built on: the phone's Energy widget and the watch's
/// energy complication. It is the step where a graph either matches the energy dashboard or quietly
/// diverges from it, and now the step where the two platforms either agree or don't.
struct EnergyStatisticsSummaryTests {
    private static let hourOne = Date(timeIntervalSince1970: 1_700_000_000)
    private static let hourTwo = Date(timeIntervalSince1970: 1_700_003_600)

    private func stats(_ byStatId: [String: [(Date, Double?)]]) -> EnergyStatistics {
        EnergyStatistics(byStatId: byStatId.mapValues { buckets in
            buckets.map { EnergyStatisticBucket(start: $0.0, change: $0.1) }
        })
    }

    private func source(type: String, from: String? = nil, to: String? = nil) -> EnergySource {
        EnergySource(type: type, statEnergyFrom: from, statEnergyTo: to)
    }

    // MARK: - Series

    /// A battery reads the opposite way round to a grid source: its `stat_energy_from` is what it
    /// gave back, where a grid source's is what the home drew in. Swapping them would stand the
    /// chart's battery bars on the wrong side of the axis.
    @Test func resolvesEachSourceTypeToItsOwnSeries() {
        let series = EnergyStatisticsSummary.Series(sources: [
            source(type: "grid", from: "grid_import", to: "grid_export"),
            source(type: "solar", from: "solar"),
            source(type: "battery", from: "battery_out", to: "battery_in"),
            source(type: "gas", from: "gas"),
        ])
        #expect(series.gridImport == ["grid_import"])
        #expect(series.gridExport == ["grid_export"])
        #expect(series.solar == ["solar"])
        #expect(series.batteryDischarge == ["battery_out"])
        #expect(series.batteryCharge == ["battery_in"])
        // Gas is a figure, never a bar on this chart, so it is deliberately absent.
        #expect(series.all.contains("gas") == false)
    }

    // MARK: - Totals

    /// Nil rather than zero: a home without panels has to stay distinguishable from one whose panels
    /// generated nothing today, or the complication would show a solar figure it has no business
    /// showing.
    @Test func anAbsentSeriesHasNoTotal() {
        let response = stats(["grid_import": [(Self.hourOne, 1.5)]])
        #expect(EnergyStatisticsSummary.total(of: ["solar"], in: response) == nil)
        #expect(EnergyStatisticsSummary.total(of: [], in: response) == nil)
        #expect(EnergyStatisticsSummary.total(of: ["grid_import"], in: response) == 1.5)
    }

    @Test func sumsEveryMeterFeedingOneSeries() {
        let response = stats([
            "grid_a": [(Self.hourOne, 1), (Self.hourTwo, 0.5)],
            "grid_b": [(Self.hourOne, 2)],
        ])
        #expect(EnergyStatisticsSummary.total(of: ["grid_a", "grid_b"], in: response) == 3.5)
    }

    /// Compensation counts upward like every other statistic, so summing it into the bill would grow
    /// the cost with every kWh returned instead of shrinking it.
    @Test func exportEarningsAreSubtractedFromTheBill() {
        let response = stats([
            "cost": [(Self.hourOne, 4)],
            "compensation": [(Self.hourOne, 1.5)],
        ])
        #expect(EnergyStatisticsSummary.netCost(cost: ["cost"], compensation: ["compensation"], in: response) == 2.5)
        #expect(EnergyStatisticsSummary.netCost(cost: [], compensation: [], in: response) == nil)
    }

    // MARK: - Chart points

    @Test func buildsOneChartPointPerBucketAcrossEverySeries() {
        let points = EnergyStatisticsSummary.chartPoints(
            for: .init(
                gridImport: ["grid_import"],
                gridExport: ["grid_export"],
                solar: ["solar"],
                batteryDischarge: ["battery_out"],
                batteryCharge: ["battery_in"]
            ),
            in: stats([
                "grid_import": [(Self.hourOne, 0.4), (Self.hourTwo, 0.1)],
                "grid_export": [(Self.hourOne, 0), (Self.hourTwo, 0.9)],
                "solar": [(Self.hourOne, 0.2), (Self.hourTwo, 1.6)],
                "battery_out": [(Self.hourTwo, 0.3)],
                "battery_in": [(Self.hourOne, 0.1)],
            ])
        )
        #expect(points.map(\.date) == [Self.hourOne, Self.hourTwo])
        #expect(points.map(\.grid) == [0.4, 0.1])
        #expect(points.map(\.gridReturned) == [0, 0.9])
        #expect(points.map(\.solar) == [0.2, 1.6])
        #expect(points.map(\.batteryDischarged) == [0, 0.3])
        #expect(points.map(\.batteryCharged) == [0.1, 0])
    }

    /// A meter that ran backwards over a bucket is a magnitude of nothing, not a bar hanging the
    /// wrong way: the chart is what decides which side of the axis a series is drawn on.
    @Test func negativeBucketsAreClampedToZero() {
        let points = EnergyStatisticsSummary.chartPoints(
            for: .init(gridImport: ["grid_import"], solar: ["solar"]),
            in: stats([
                "grid_import": [(Self.hourOne, -0.3)],
                "solar": [(Self.hourOne, 0.5)],
            ])
        )
        #expect(points.map(\.grid) == [0])
        #expect(points.map(\.solar) == [0.5])
    }

    /// The share a bucket's generation actually covered, which is what the bars stack — plotting the
    /// raw generation would count everything exported twice.
    @Test func splitsABucketTheWayTheDashboardDoes() {
        let points = EnergyStatisticsSummary.chartPoints(
            for: .init(gridImport: ["grid_import"], gridExport: ["grid_export"], solar: ["solar"]),
            in: stats([
                "grid_import": [(Self.hourOne, 0.05)],
                "grid_export": [(Self.hourOne, 0.97)],
                "solar": [(Self.hourOne, 1.7)],
            ])
        )
        #expect(points.count == 1)
        #expect(abs(points[0].solarUsed - 0.73) < 0.0001)
    }

    @Test func aResponseWithNothingInItYieldsNoPoints() {
        #expect(EnergyStatisticsSummary.chartPoints(
            for: .init(gridImport: ["grid_import"]),
            in: stats([:])
        ).isEmpty)
    }
}
