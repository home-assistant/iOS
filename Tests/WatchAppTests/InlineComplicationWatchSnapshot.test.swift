import HAWatchComplications
import SwiftUI
import Testing

/// Renders the shared `InlineComplicationContentView` on **watchOS**, capturing the real watchOS font
/// metrics for the inline line. Companion to the iOS `InlineComplicationSnapshotTests`.
struct InlineComplicationWatchSnapshotTests {
    @MainActor @Test func inlineComplicationVariants() {
        for (name, model) in Self.variants {
            // Prefixed per family: this target is a synchronized folder that copies snapshot PNGs
            // into the .xctest bundle flat, so identical basenames across families would collide.
            assertWatchSnapshot(face(model), named: "inline-\(name)")
        }
    }

    private func face(_ model: InlineComplicationRenderModel) -> some View {
        InlineComplicationContentView(model: model)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(width: 180, height: 44)
            .background(.black)
            .environment(\.colorScheme, .dark)
    }

    private static var variants: [(String, InlineComplicationRenderModel)] {
        [
            ("name-and-value", .sample()),
            ("value-only", .sample(text: "72%")),
            ("name-only", .sample(text: "Living Room")),
            ("long-line", .sample(text: "Basement Dehumidifier - 1234 L")),
        ]
    }
}
