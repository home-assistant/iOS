import HAWatchComplications
import SharedTesting
import SwiftUI
import Testing

/// Snapshots the shared `CornerComplicationContentView` — the manual-arc rendering the in-app editor
/// preview (`CornerComplicationPreview`) uses and that snapshot-tests the corner layout logic.
///
/// The real watch corner complication renders via the native `widgetCurvesContent()` / `widgetLabel`
/// APIs (which only work inside a widget host), so this covers the shared approximation, not the
/// on-device bezel curving. Both sides resolve text / gauge through `CornerComplicationRenderModel`.
struct CornerComplicationSnapshotTests {
    @MainActor @Test func cornerComplicationVariants() {
        for (name, model) in Self.variants {
            assertSnapshot(
                of: face(model),
                layout: .fixed(width: 120, height: 120),
                traits: .init(userInterfaceStyle: .dark),
                named: name
            )
        }
    }

    private func face(_ model: CornerComplicationRenderModel) -> some View {
        CornerComplicationContentView(model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
    }

    /// The icon slot carrying a configured color, which the face has to draw instead of tinting it away.
    private static func customIconColor(
        _ model: CornerComplicationRenderModel
    ) -> CornerComplicationRenderModel {
        var model = model
        model.iconImage = customColoredComplicationIcon()
        return model
    }

    private static var variants: [(String, CornerComplicationRenderModel)] {
        [
            ("icon-name-value-gauge", .sample()),
            ("custom-icon-color", customIconColor(.sample(showValue: false, title: nil, fraction: nil))),
            ("value-name-gauge", .sample(icon: false)),
            ("value-name-no-gauge", .sample(icon: false, fraction: nil)),
            ("value-only", .sample(icon: false, title: nil, fraction: nil)),
            ("name-only-gauge", .sample(icon: false, showValue: false)),
            ("icon-gauge", .sample(showValue: false, title: nil)),
            ("icon-only", .sample(showValue: false, title: nil, fraction: nil)),
            ("zero-fraction", .sample(value: "0%", fraction: 0)),
            ("full-fraction", .sample(value: "100%", fraction: 1)),
            ("custom-text-color", .sample(textColor: .yellow)),
            // The rain-sparkline recipe: an icon plus a block-element bar graph, which only reads as a
            // graph while its cells stay flat, abutting and all on screen.
            ("icon-block-sparkline", .sample(value: "▁▂▃▄▅▆▇█", title: nil, fraction: nil)),
            // A legacy Graphic Corner "Gauge Text" complication: ClockKit drew its outer text flat and
            // large in the corner tip, so it opts out of the curve and keeps that size.
            ("flat-outer-text-gauge", .sample(icon: false, value: "16.6", title: nil, curvesText: false)),
        ]
    }
}
