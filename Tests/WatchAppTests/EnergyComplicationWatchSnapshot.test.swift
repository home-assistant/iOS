import HAWatchComplications
import SwiftUI
import Testing
import WidgetKit

/// Renders the shared `EnergyComplicationContentView` on **watchOS** (this target runs on a watch
/// simulator), at the size a rectangular complication actually gets on the face.
///
/// That size is the whole point of the references: the complication has to fit a day's figures and a
/// day's chart into about fifty points of height, so a layout change that looks fine in a preview
/// can still crush the chart on the watch. These images are where that shows up.
struct EnergyComplicationWatchSnapshotTests {
    /// A 45mm watch's rectangular complication, in points. The other sizes scale from it, so the
    /// tightest realistic case is the one worth pinning.
    private static let complicationSize = CGSize(width: 171, height: 50)

    @MainActor @Test func energyComplicationVariants() {
        for (name, model) in Self.variants {
            assertWatchSnapshot(face(model), named: name)
        }
    }

    /// The same complication in each of the face's rendering modes. Outside full colour the system
    /// flattens the series colours to luminance, so the view swaps them for the accent — this is
    /// what checks the bars stay told apart when it does.
    @MainActor @Test func renderingModeVariants() {
        let model = EnergyComplicationRenderModel(
            stats: EnergyComplicationSampleData.stats,
            bars: EnergyComplicationSampleData.bars
        )
        for mode in [WidgetRenderingMode.fullColor, .accented, .vibrant] {
            assertWatchSnapshot(face(model, mode: mode), named: "energy-mode-\(mode)")
        }
    }

    private func face(
        _ model: EnergyComplicationRenderModel,
        mode: WidgetRenderingMode = .fullColor
    ) -> some View {
        EnergyComplicationContentView(model: model)
            .environment(\.widgetRenderingMode, mode)
            .frame(width: Self.complicationSize.width, height: Self.complicationSize.height)
            .background(.black)
            // The watch face is black with light content, so default `.primary` text is white.
            .environment(\.colorScheme, .dark)
    }

    /// Named with the family prefix the other watch references use: the test bundle flattens its
    /// resources, so two families' variants must not collide on a bare name.
    ///
    /// The list is the shapes an energy dashboard actually takes, not a power set: which series a
    /// home has is whatever it configured, and each combination lands differently. A battery adds
    /// two colours to the chart and a figure whose sign runs the opposite way to the grid's; gas
    /// adds a figure and no bar at all, in a unit that may not even be kWh. Both are configured far
    /// more often on their own than together, so both are drawn on their own here.
    private static var variants: [(String, EnergyComplicationRenderModel)] {
        [
            ("energy-grid-and-solar", .init(stats: sampleStats, bars: EnergyComplicationSampleData.bars)),
            ("energy-every-source", .init(
                stats: EnergyComplicationSampleData.allSourceStats,
                bars: EnergyComplicationSampleData.batteryBars
            )),

            // Solar and a battery, which is the pairing a battery is nearly always installed with:
            // the surplus is stored at midday and given back over the evening peak, so the chart
            // carries both battery colours — discharge stacked above the axis, charge below it.
            ("energy-with-battery", setup(EnergyComplicationSampleData.batteryBars)),
            // A battery charged from the grid rather than from panels, on a tariff worth arbitraging.
            ("energy-battery-without-solar", setup(gridChargedBatteryBars)),
            // A period the battery took more from the home than it gave back. The figure is a
            // magnitude, so it reads the same as a discharging day — the chart is what says which
            // way the period went, and here it hangs below the axis.
            ("energy-battery-charging", setup(chargingBatteryBars)),

            // Gas alongside electricity, the common European shape. Two figures, so this is also
            // where a unit that isn't kWh has to sit legibly next to one that is.
            ("energy-grid-and-gas", setup(gridOnlyBars, gas: 4.8)),
            // A gas meter that reports energy content rather than volume: the recorder decides the
            // unit, and here it is the same kWh as everything else.
            ("energy-gas-in-kwh", setup(
                gridOnlyBars,
                gas: 52.4,
                gasUnit: EnergyComplicationStat.energyUnit
            )),
            // Gas on its own. Nothing to plot — gas is never a bar — so the chart is its baseline
            // and nothing else, which still has to look deliberate rather than broken.
            ("energy-gas-only", setup([], gas: 4.8)),

            ("energy-with-server-name", .init(
                stats: sampleStats,
                bars: EnergyComplicationSampleData.bars,
                serverName: "Home"
            )),
            // Statistics that have only just started arriving: the figures are there, the chart is
            // still mostly axis. It has to look like a chart waiting for data rather than a bug.
            ("energy-day-just-started", .init(
                stats: sampleStats,
                bars: Array(EnergyComplicationSampleData.bars.prefix(3))
            )),
            ("energy-no-data", .init(message: "No energy data")),
            ("energy-not-configured", .init(
                serverName: "Holiday home",
                message: "No energy dashboard configured"
            )),
            // Four-digit figures are what a month of a large home looks like; they must not push the
            // row into an ellipsis.
            ("energy-long-figures", .init(
                stats: [
                    .energy(.grid, kWh: 1234.5),
                    .energy(.solar, kWh: 987.6),
                ],
                bars: EnergyComplicationSampleData.bars
            )),
        ]
    }

    private static var sampleStats: [EnergyComplicationStat] {
        EnergyComplicationSampleData.stats
    }

    /// One dashboard shape, with its figures derived from its own buckets so the numbers above the
    /// chart always describe the bars under them — the same relationship the watch app produces,
    /// where both come out of one statistics response.
    private static func setup(
        _ bars: [EnergyComplicationChartBar],
        gas: Double? = nil,
        gasUnit: String = "m³"
    ) -> EnergyComplicationRenderModel {
        .init(
            stats: EnergyComplicationSampleData.stats(for: bars, gas: gas, gasUnit: gasUnit),
            bars: bars
        )
    }

    /// A home with no panels: everything it used came off the grid, and nothing left the property.
    private static var gridOnlyBars: [EnergyComplicationChartBar] {
        EnergyComplicationSampleData.bars.map { bar in
            EnergyComplicationChartBar(
                date: bar.date,
                solarUsed: 0,
                gridUsed: bar.gridUsed + bar.solarUsed
            )
        }
    }

    /// A battery on a home with no panels, charged off-peak from the grid and discharged into the
    /// evening — so the chart has to hold both battery colours with no solar between them.
    private static var gridChargedBatteryBars: [EnergyComplicationChartBar] {
        EnergyComplicationSampleData.batteryBars.map { bar in
            EnergyComplicationChartBar(
                date: bar.date,
                solarUsed: 0,
                batteryUsed: bar.batteryUsed,
                gridUsed: bar.gridUsed + bar.solarUsed,
                batteryCharged: bar.batteryCharged
            )
        }
    }

    /// A period that put far more into the battery than it took back out.
    private static var chargingBatteryBars: [EnergyComplicationChartBar] {
        EnergyComplicationSampleData.batteryBars.map { bar in
            EnergyComplicationChartBar(
                date: bar.date,
                solarUsed: bar.solarUsed,
                batteryUsed: bar.batteryUsed * 0.2,
                gridUsed: bar.gridUsed,
                batteryCharged: bar.batteryCharged * 3,
                gridReturned: bar.gridReturned
            )
        }
    }
}
