import HAWatchComplications
import SharedTesting
import SwiftUI
import Testing
import WidgetKit

/// Snapshots the shared `CircularComplicationContentView` — the exact same view the watchOS
/// complication (`CircularComplicationView`) renders and that the in-app editor preview
/// (`CircularComplicationPreview`) drives via `CircularComplicationRenderModel`. These references are
/// the source of truth for how the circular complication looks; a preview that diverges will change
/// these images.
///
/// Rendered dark on a black face to mirror the watch, where the face is black and text defaults to
/// `.primary` (white).
struct CircularComplicationSnapshotTests {
    @MainActor @Test func circularComplicationVariants() {
        for (name, model) in Self.variants {
            assertSnapshot(
                of: face(model),
                layout: .fixed(width: 120, height: 120),
                traits: .init(userInterfaceStyle: .dark),
                named: name
            )
        }
    }

    private func face(_ model: CircularComplicationRenderModel) -> some View {
        CircularComplicationContentView(model: model)
            .frame(width: 100, height: 100)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
    }

    private static var variants: [(String, CircularComplicationRenderModel)] {
        [
            ("icon-value-name-open", .sample()),
            ("no-min-max", .sample(showMinMax: false)),
            ("value-only", .sample(icon: false, title: nil)),
            ("value-and-name-no-icon", .sample(icon: false)),
            ("icon-and-value-no-name", .sample(title: nil)),
            // Icon + value with the min/max labels hidden: the value moves into the open gauge's free
            // bottom slot and the icon leads the center at full size (see `isIconLedWithBottomValue`).
            // "no-min-max" above is the same layout with a name captioning the icon.
            ("icon-led-value-at-bottom", .sample(title: nil, showMinMax: false)),
            ("capacity-ring", .sample(capacity: true)),
            ("no-gauge", .sample(fraction: nil)),
            ("icon-only-no-gauge", .sample(value: "", showValue: false, title: nil, fraction: nil)),
            ("zero-fraction", .sample(value: "0%", fraction: 0)),
            ("full-fraction", .sample(value: "100%", fraction: 1)),
            ("long-value", .sample(icon: false, value: "1234", title: nil)),
            ("custom-text-color", .sample(title: "Solar", textColor: .yellow)),
        ]
    }
}
