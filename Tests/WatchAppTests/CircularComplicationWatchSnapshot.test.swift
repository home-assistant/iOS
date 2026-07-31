import HAWatchComplications
import SwiftUI
import Testing

/// Renders the shared `CircularComplicationContentView` on **watchOS**, capturing the real watchOS
/// gauge metrics, fonts, and scale the complication actually uses. Companion to the iOS
/// `CircularComplicationSnapshotTests`, which renders the same view/models on iOS.
struct CircularComplicationWatchSnapshotTests {
    @MainActor @Test func circularComplicationVariants() {
        for (name, model) in Self.variants {
            // Prefixed per family: this target is a synchronized folder that copies snapshot PNGs
            // into the .xctest bundle flat, so identical basenames across families would collide.
            assertWatchSnapshot(face(model), named: "circular-\(name)")
        }
    }

    private func face(_ model: CircularComplicationRenderModel) -> some View {
        CircularComplicationContentView(model: model)
            .frame(width: 100, height: 100)
            .background(.black)
            // The watch face is black with light content, so default `.primary` text is white.
            .environment(\.colorScheme, .dark)
    }

    private static var variants: [(String, CircularComplicationRenderModel)] {
        [
            ("icon-value-name-open", .sample()),
            ("no-min-max", .sample(showMinMax: false)),
            ("value-only", .sample(icon: false, title: nil)),
            ("value-and-name-no-icon", .sample(icon: false)),
            ("icon-and-value-no-name", .sample(title: nil)),
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
