@testable import HomeAssistant

import Foundation
import Shared
import Testing

/// Covers gas, which is the one energy source the widget can't treat as electricity. A gas meter
/// reports volume as often as it reports energy content, so the figure carries a unit the recorder
/// supplies rather than kWh — and it is priced, so it belongs in the card's cost alongside the grid
/// the way the energy dashboard's totals row adds them together.
struct WidgetEnergyGasTests {
    private static let hourOne = Date(timeIntervalSince1970: 1_700_000_000)

    private func stats(_ byStatId: [String: Double]) -> EnergyStatistics {
        EnergyStatistics(byStatId: byStatId.mapValues { change in
            [EnergyStatisticBucket(start: Self.hourOne, change: change)]
        })
    }

    private func cents(_ value: Double?) -> Double? {
        value.map { ($0 * 100).rounded() / 100 }
    }

    // MARK: - Figure

    /// The unit comes from the entry, not from the palette: a cubic-metre meter labelled kWh would
    /// misreport the reading by roughly a factor of ten.
    @available(iOS 17, *)
    @Test func gasCarriesTheUnitTheRecorderReported() {
        let entry = WidgetEnergyEntry(isConfigured: true, gasConsumed: 4.8, gasUnit: "m³")
        // Only the unit: the number itself is locale-formatted, and the decimal separator is not
        // this test's business.
        #expect(WidgetEnergyMetric.gas(for: entry)?.unit == "m³")
    }

    /// A meter that reports energy content is still gas, and still gets its own figure — it just
    /// happens to share the electricity unit.
    @available(iOS 17, *)
    @Test func aGasMeterReportingEnergyKeepsItsOwnFigure() {
        let entry = WidgetEnergyEntry(
            isConfigured: true,
            gasConsumed: 12.0,
            gasUnit: WidgetEnergyStyle.energyUnit
        )
        #expect(WidgetEnergyMetric.gas(for: entry)?.unit == WidgetEnergyStyle.energyUnit)
    }

    /// Gas is only ever drawn from, so the arrow points the same way the grid's does when importing.
    @available(iOS 17, *)
    @Test func gasConsumptionPointsDown() {
        let entry = WidgetEnergyEntry(isConfigured: true, gasConsumed: 4.8, gasUnit: "m³")
        #expect(WidgetEnergyMetric.gas(for: entry)?.direction == .down)
    }

    /// A home with no gas drops the series rather than showing a blank one beside real figures.
    @available(iOS 17, *)
    @Test func noGasMeansNoMetric() {
        #expect(WidgetEnergyMetric.gas(for: WidgetEnergyEntry(isConfigured: true, gridConsumed: 6.2)) == nil)
    }

    /// Gas statistics alone are enough to say the period had data.
    @available(iOS 17, *)
    @Test func gasTotalsCountAsPeriodData() {
        #expect(WidgetEnergyEntry(isConfigured: true, gasConsumed: 4.8, gasUnit: "m³").hasStatistics)
    }

    /// Grid leads and gas comes last: the order the widget draws every layout in.
    @available(iOS 17, *)
    @Test func everySourceAppearsInHeadlineOrder() {
        let entry = WidgetEnergyEntry(
            isConfigured: true,
            gridConsumed: 6.2,
            solarGenerated: 12.4,
            batteryDischarged: 2.5,
            gasConsumed: 4.8,
            gasUnit: "m³"
        )
        #expect(
            WidgetEnergyMetric.metrics(for: entry, figure: .totals).map(\.kind) == [.grid, .solar, .battery, .gas]
        )
    }

    // MARK: - Cost

    /// The bill covers every priced source, the way the dashboard's totals row does: €2.03 of
    /// electricity plus €1.30 of gas, less €0.22 earned exporting.
    @available(iOS 17, *)
    @Test func gasCostJoinsTheElectricityBill() {
        let ids = WidgetEnergyAppIntentTimelineProvider.costStatIds(
            gridSources: [
                EnergySource(
                    type: "grid",
                    statEnergyFrom: "grid_import",
                    statEnergyTo: "grid_export",
                    statCost: "grid_cost",
                    statCompensation: "grid_compensation"
                ),
            ],
            gasSources: [EnergySource(type: "gas", statEnergyFrom: "gas_consumed", statCost: "gas_cost")],
            info: nil
        )
        #expect(ids.cost == ["grid_cost", "gas_cost"])
        #expect(ids.compensation == ["grid_compensation"])

        let cost = WidgetEnergyAppIntentTimelineProvider.netCost(
            cost: ids.cost,
            compensation: ids.compensation,
            in: stats(["grid_cost": 2.03, "gas_cost": 1.30, "grid_compensation": 0.22])
        )
        #expect(cents(cost) == 3.11)
    }

    /// A gas source with no `stat_cost` of its own falls back to the auto-generated cost sensor from
    /// `energy/info`, exactly as a grid source does.
    @available(iOS 17, *)
    @Test func gasFallsBackToTheGeneratedCostSensor() {
        let ids = WidgetEnergyAppIntentTimelineProvider.costStatIds(
            gridSources: [],
            gasSources: [EnergySource(type: "gas", statEnergyFrom: "gas_consumed")],
            info: EnergyInfo(costSensors: ["gas_consumed": "gas_cost"], solarForecastDomains: [])
        )
        #expect(ids.cost == ["gas_cost"])
        #expect(ids.compensation.isEmpty)
    }

    /// Gas has nothing to sell back, so it never reaches the compensation side — a gas source's
    /// `stat_energy_to` is not an export meter and must not be netted off the bill.
    @available(iOS 17, *)
    @Test func gasNeverEarnsCompensation() {
        let ids = WidgetEnergyAppIntentTimelineProvider.costStatIds(
            gridSources: [],
            gasSources: [EnergySource(type: "gas", statEnergyFrom: "gas_consumed", statCost: "gas_cost")],
            info: nil
        )
        #expect(ids.compensation.isEmpty)
    }

    // MARK: - Unit metadata

    /// The recorder's metadata is what says whether a gas meter reads volume or energy; the energy
    /// preferences don't carry it.
    @available(iOS 17, *)
    @Test func metadataResolvesTheUnitClassAndDisplayUnit() {
        let metadata = EnergyStatisticsMetadata(byStatId: [
            "gas_consumed": .init(unitClass: "volume", displayUnit: "m³"),
        ])
        #expect(metadata.commonUnitClass(of: ["gas_consumed"]) == "volume")
        #expect(metadata.commonDisplayUnit(of: ["gas_consumed"]) == "m³")
    }

    /// Meters that disagree have no single unit to convert to, so the caller is left to fall back
    /// rather than handed whichever id sorted first.
    @available(iOS 17, *)
    @Test func disagreeingMetersResolveToNothing() {
        let metadata = EnergyStatisticsMetadata(byStatId: [
            "gas_a": .init(unitClass: "volume", displayUnit: "m³"),
            "gas_b": .init(unitClass: "energy", displayUnit: "kWh"),
        ])
        #expect(metadata.commonUnitClass(of: ["gas_a", "gas_b"]) == nil)
        #expect(metadata.commonDisplayUnit(of: ["gas_a", "gas_b"]) == nil)
    }

    /// A statistic the recorder can't convert has no unit class at all, which is not an error —
    /// it just means the widget falls back to the home's measurement system.
    @available(iOS 17, *)
    @Test func unknownStatisticsResolveToNothing() {
        let metadata = EnergyStatisticsMetadata(byStatId: [:])
        #expect(metadata.commonUnitClass(of: ["gas_consumed"]) == nil)
    }
}
