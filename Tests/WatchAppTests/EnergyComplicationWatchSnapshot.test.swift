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
    private static var variants: [(String, EnergyComplicationRenderModel)] {
        [
            ("energy-grid-and-solar", .init(stats: sampleStats, bars: EnergyComplicationSampleData.bars)),
            ("energy-every-source", .init(
                stats: EnergyComplicationSampleData.allSourceStats,
                bars: EnergyComplicationSampleData.batteryBars
            )),
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
}
