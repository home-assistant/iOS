import HAWatchComplications
import SwiftUI
import Testing

/// Renders the shared `RectangularComplicationContentView` on **watchOS** (this target runs on a watch
/// simulator), capturing the real watchOS font metrics, scale, and layout the complication actually
/// uses — the closest automated check to the on-face rendering. Companion to the iOS
/// `RectangularComplicationSnapshotTests`, which renders the same view/models on iOS; comparing the two
/// reference sets shows exactly where the platforms diverge.
struct RectangularComplicationWatchSnapshotTests {
    @MainActor @Test func rectangularComplicationVariants() {
        for (name, model) in Self.variants {
            assertWatchSnapshot(face(model), named: name)
        }
    }

    private func face(_ model: RectangularComplicationRenderModel) -> some View {
        RectangularComplicationContentView(model: model)
            .padding(12)
            .frame(width: 180, alignment: .leading)
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
