import HAWatchComplications
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

/// Snapshots the shared `EnergyComplicationContentView` — the exact view the watch complication
/// renders — on iOS.
///
/// Companion to the watchOS `EnergyComplicationWatchSnapshotTests`, which renders the same models at
/// the size a rectangular complication actually gets on the face. That target runs on a watch
/// simulator and its results never reach the coverage report, so this is also what keeps the view
/// and its chart exercised by the suite the project measures.
///
/// Rendered dark on a black face to mirror the watch, where the face is black and text defaults to
/// `.primary` (white). A light rendering would draw the default text black-on-black, so it isn't
/// representative and isn't captured.
struct EnergyComplicationSnapshotTests {
    @MainActor @Test func energyComplicationVariants() {
        for (name, model) in Self.variants {
            assertSnapshot(
                of: face(model),
                layout: .fixed(width: 220, height: 120),
                traits: .init(userInterfaceStyle: .dark),
                named: name
            )
        }
    }

    /// The complication also renders in the watch face's accented and vibrant modes. This captures
    /// how the shared view *adapts* to each `widgetRenderingMode` — the series colours give way to
    /// weights of the accent — rather than the system's own face-wide compositing, which only
    /// happens on-device.
    @MainActor @Test func renderingModeVariants() {
        let model = EnergyComplicationRenderModel(
            stats: EnergyComplicationSampleData.stats,
            bars: EnergyComplicationSampleData.bars
        )
        for mode in [WidgetRenderingMode.fullColor, .accented, .vibrant] {
            assertSnapshot(
                of: face(model, mode: mode),
                layout: .fixed(width: 220, height: 120),
                traits: .init(userInterfaceStyle: .dark),
                named: "\(mode)"
            )
        }
    }

    private func face(
        _ model: EnergyComplicationRenderModel,
        mode: WidgetRenderingMode = .fullColor
    ) -> some View {
        EnergyComplicationContentView(model: model)
            .environment(\.widgetRenderingMode, mode)
            .frame(width: 171, height: 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(.black)
    }

    private static var variants: [(String, EnergyComplicationRenderModel)] {
        [
            ("grid-and-solar", .init(
                stats: EnergyComplicationSampleData.stats,
                bars: EnergyComplicationSampleData.bars
            )),
            ("every-source", .init(
                stats: EnergyComplicationSampleData.allSourceStats,
                bars: EnergyComplicationSampleData.batteryBars
            )),
            ("with-server-name", .init(
                stats: EnergyComplicationSampleData.stats,
                bars: EnergyComplicationSampleData.bars,
                serverName: "Home"
            )),
            // Gas is never a bar, so a dashboard carrying it alone has nothing to plot and the chart
            // is left out rather than drawn as a bare axis.
            ("gas-only", .init(
                stats: EnergyComplicationSampleData.stats(for: [], gas: 4.8),
                bars: []
            )),
            ("no-data", .init(message: "No energy data")),
        ]
    }
}
