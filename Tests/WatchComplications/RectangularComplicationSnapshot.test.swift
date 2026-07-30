import HAWatchComplications
import SharedTesting
import SwiftUI
import Testing

/// Snapshots the shared `RectangularComplicationContentView` — the exact same view the watchOS
/// complication (`RectangularComplicationView`) renders. Because the watch and the in-app editor
/// preview both drive this one view via `RectangularComplicationRenderModel`, these references are
/// the source of truth for how the rectangular complication looks; a preview that diverges will
/// change these images.
///
/// Rendered dark on a black face to mirror the watch, where the face is black and text defaults to
/// `.primary` (white). A light rendering would draw the default text black-on-black, so it isn't
/// representative and isn't captured.
struct RectangularComplicationSnapshotTests {
    @MainActor @Test func rectangularComplicationVariants() {
        for (name, model) in Self.variants {
            assertSnapshot(
                of: face(model),
                layout: .fixed(width: 220, height: 120),
                traits: .init(userInterfaceStyle: .dark),
                named: name
            )
        }
    }

    private func face(_ model: RectangularComplicationRenderModel) -> some View {
        RectangularComplicationContentView(model: model)
            .padding(12)
            .frame(width: 200, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.black)
    }

    private static var variants: [(String, RectangularComplicationRenderModel)] {
        [
            ("icon-name-gauge", .sample()),
            ("all-slots", .sample(title: "Living Room", subtitle: "Temperature", bottomText: "Updated 2m ago")),
            ("value-as-text", .sample(title: "Front Door", subtitle: "Lock", fraction: nil, value: "Locked")),
            ("text-only", .sample(title: "Bedroom", subtitle: "All quiet", fraction: nil, showValue: false)),
            ("no-icon", .sample(icon: false, title: "Humidity", subtitle: "Bathroom", value: "54%")),
            ("custom-text-color", .sample(
                title: "Solar",
                subtitle: "Production",
                value: "82%",
                bottomText: "Peak 4.2 kW",
                textColor: .yellow
            )),
        ]
    }
}
