@testable import HomeAssistant

import Foundation
import Shared
import Testing

/// Covers the money side of the energy widget. Cost and compensation statistics both count upward,
/// so the direction each one pulls the total is entirely the widget's own doing — get it wrong and
/// the card quietly reports a bill that grows every time the home exports.
struct WidgetEnergyCostTests {
    private static let hourOne = Date(timeIntervalSince1970: 1_700_000_000)

    /// Money in binary floating point doesn't land on exact decimals — 2.03 − 0.22 comes out a hair
    /// under 1.81 — so these compare at the resolution the widget actually renders.
    private func cents(_ value: Double?) -> Double? {
        value.map { ($0 * 100).rounded() / 100 }
    }

    private func stats(_ byStatId: [String: Double]) -> EnergyStatistics {
        EnergyStatistics(byStatId: byStatId.mapValues { change in
            [EnergyStatisticBucket(start: Self.hourOne, change: change)]
        })
    }

    /// The reported case: €2.03 of imports against €0.22 earned exporting is a €1.81 bill, not €2.25.
    @available(iOS 17, *)
    @Test func exportEarningsAreSubtractedFromTheBill() {
        let cost = WidgetEnergyAppIntentTimelineProvider.netCost(
            cost: ["grid_cost"],
            compensation: ["grid_compensation"],
            in: stats(["grid_cost": 2.03, "grid_compensation": 0.22])
        )
        #expect(cents(cost) == 1.81)
    }

    /// A home that earns more than it spends ends the period in credit.
    @available(iOS 17, *)
    @Test func aPeriodInCreditComesBackNegative() {
        let cost = WidgetEnergyAppIntentTimelineProvider.netCost(
            cost: ["grid_cost"],
            compensation: ["grid_compensation"],
            in: stats(["grid_cost": 0.30, "grid_compensation": 0.79])
        )
        #expect(cents(cost) == -0.49)
    }

    /// Every tariff's statistics are summed within its own direction before the two are netted off.
    @available(iOS 17, *)
    @Test func tariffsAreSummedWithinEachDirection() {
        let cost = WidgetEnergyAppIntentTimelineProvider.netCost(
            cost: ["tariff_1_cost", "tariff_2_cost"],
            compensation: ["tariff_1_compensation", "tariff_2_compensation"],
            in: stats([
                "tariff_1_cost": 2.0,
                "tariff_2_cost": 1.0,
                "tariff_1_compensation": 0.2,
                "tariff_2_compensation": 0.1,
            ])
        )
        #expect(cents(cost) == 2.7)
    }

    /// Compensation without a matching cost statistic is still money back, so the period reads as
    /// credit rather than as a bill.
    @available(iOS 17, *)
    @Test func compensationAloneIsStillCredit() {
        let cost = WidgetEnergyAppIntentTimelineProvider.netCost(
            cost: ["grid_cost"],
            compensation: ["grid_compensation"],
            in: stats(["grid_compensation": 0.22])
        )
        #expect(cents(cost) == -0.22)
    }

    /// A dashboard that tracks no money at all has no total to show, which is distinct from €0.
    @available(iOS 17, *)
    @Test func noMonetaryStatisticsMeansNoTotal() {
        let cost = WidgetEnergyAppIntentTimelineProvider.netCost(
            cost: ["grid_cost"],
            compensation: ["grid_compensation"],
            in: stats(["grid_import": 9.38])
        )
        #expect(cost == nil)
    }

    /// The two directions have to resolve to separate lists: `stat_compensation` describes exports,
    /// and the `energy/info` cost sensors fill in for a source that names neither explicitly.
    @available(iOS 17, *)
    @Test func costIdsAreSplitByDirection() {
        let ids = WidgetEnergyAppIntentTimelineProvider.costStatIds(
            gridSources: [
                EnergySource(
                    type: "grid",
                    statEnergyFrom: "import_tariff_1",
                    statEnergyTo: "export_tariff_1",
                    statCost: "cost_tariff_1",
                    statCompensation: "compensation_tariff_1"
                ),
                EnergySource(type: "grid", statEnergyFrom: "import_tariff_2", statEnergyTo: "export_tariff_2"),
            ],
            info: EnergyInfo(
                costSensors: ["import_tariff_2": "cost_tariff_2", "export_tariff_2": "compensation_tariff_2"],
                solarForecastDomains: []
            )
        )

        #expect(ids.cost == ["cost_tariff_1", "cost_tariff_2"])
        #expect(ids.compensation == ["compensation_tariff_1", "compensation_tariff_2"])
    }
}
