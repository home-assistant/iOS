@testable import HomeAssistant

import Foundation
import Shared
import Testing

/// Covers the aggregation that feeds the energy chart. It is the step where the widget's graph
/// either matches the energy dashboard or quietly diverges from it: every series the dashboard
/// stacks has to survive the trip from `recorder/statistics_during_period` into a chart point.
struct WidgetEnergyChartPointsTests {
    private static let hourOne = Date(timeIntervalSince1970: 1_700_000_000)
    private static let hourTwo = Date(timeIntervalSince1970: 1_700_003_600)

    private func stats(_ byStatId: [String: [(Date, Double?)]]) -> EnergyStatistics {
        EnergyStatistics(byStatId: byStatId.mapValues { buckets in
            buckets.map { EnergyStatisticBucket(start: $0.0, change: $0.1) }
        })
    }

    @available(iOS 17, *)
    @Test func carriesEnergyReturnedToTheGrid() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: ["grid_import"],
            exportIds: ["grid_export"],
            solarIds: ["solar"],
            in: stats([
                "grid_import": [(Self.hourOne, 0.4), (Self.hourTwo, 0.1)],
                "grid_export": [(Self.hourOne, 0), (Self.hourTwo, 0.9)],
                "solar": [(Self.hourOne, 0.2), (Self.hourTwo, 1.6)],
            ])
        )
        #expect(points.map(\.gridReturned) == [0, 0.9])
        #expect(points.map(\.grid) == [0.4, 0.1])
        #expect(points.map(\.solar) == [0.2, 1.6])
    }

    /// A bucket that exported most of its generation must plot only what the home kept — the widget
    /// used to stack the full generation, so its orange bar overshot the dashboard's by the exported
    /// amount.
    @available(iOS 17, *)
    @Test func solarUsedExcludesWhatWasExported() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: ["grid_import"],
            exportIds: ["grid_export"],
            solarIds: ["solar"],
            in: stats([
                "grid_import": [(Self.hourOne, 0.05)],
                "grid_export": [(Self.hourOne, 0.97)],
                "solar": [(Self.hourOne, 1.7)],
            ])
        )
        #expect(points.count == 1)
        #expect(abs(points[0].solarUsed - 0.73) < 0.0001)
    }

    /// Homes with more than one meter per direction are summed into a single series, the way the
    /// dashboard's own graph combines them.
    @available(iOS 17, *)
    @Test func sumsEveryStatisticFeedingASeries() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: ["import_a", "import_b"],
            exportIds: ["export_a", "export_b"],
            solarIds: ["solar_a", "solar_b"],
            in: stats([
                "import_a": [(Self.hourOne, 0.3)],
                "import_b": [(Self.hourOne, 0.2)],
                "export_a": [(Self.hourOne, 0.1)],
                "export_b": [(Self.hourOne, 0.4)],
                "solar_a": [(Self.hourOne, 1.0)],
                "solar_b": [(Self.hourOne, 0.5)],
            ])
        )
        #expect(points.count == 1)
        #expect(abs(points[0].grid - 0.5) < 0.0001)
        #expect(abs(points[0].gridReturned - 0.5) < 0.0001)
        #expect(abs(points[0].solar - 1.5) < 0.0001)
    }

    /// A bucket present only in the export statistic still produces a point: an hour that did
    /// nothing but export is a real hour, and dropping it would leave a gap in the bars.
    @available(iOS 17, *)
    @Test func bucketsPresentInOnlyOneSeriesStillAppear() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: ["grid_import"],
            exportIds: ["grid_export"],
            solarIds: ["solar"],
            in: stats([
                "grid_import": [(Self.hourOne, 0.4)],
                "grid_export": [(Self.hourTwo, 0.6)],
                "solar": [],
            ])
        )
        #expect(points.map(\.date) == [Self.hourOne, Self.hourTwo])
        #expect(points.map(\.gridReturned) == [0, 0.6])
        #expect(points.map(\.grid) == [0.4, 0])
    }

    /// Meters occasionally report a negative change after a correction; the chart draws magnitudes
    /// and decides the side of the axis itself, so a negative would flip a bar the wrong way.
    @available(iOS 17, *)
    @Test func clampsNegativeChangesToZero() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: ["grid_import"],
            exportIds: ["grid_export"],
            solarIds: ["solar"],
            in: stats([
                "grid_import": [(Self.hourOne, -0.3)],
                "grid_export": [(Self.hourOne, -0.2)],
                "solar": [(Self.hourOne, -0.1)],
            ])
        )
        #expect(points == [.init(date: Self.hourOne, grid: 0, solar: 0, gridReturned: 0)])
    }

    /// Missing `change` values shouldn't be mistaken for data, but the bucket still exists.
    @available(iOS 17, *)
    @Test func treatsMissingChangeAsZero() {
        let points = WidgetEnergyAppIntentTimelineProvider.chartPoints(
            importIds: ["grid_import"],
            exportIds: [],
            solarIds: [],
            in: stats(["grid_import": [(Self.hourOne, nil), (Self.hourTwo, 0.2)]])
        )
        #expect(points.map(\.grid) == [0, 0.2])
    }
}
