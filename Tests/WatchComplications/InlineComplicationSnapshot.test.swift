import HAWatchComplications
import SharedTesting
import SwiftUI
import Testing

/// Snapshots the shared `InlineComplicationContentView` — the single line the watchOS complication
/// (`InlineComplicationView`) renders and that the in-app editor preview (`InlineComplicationPreview`)
/// drives via `InlineComplicationRenderModel`.
///
/// Inline has no icon or custom colors; watchOS renders it in the face's tint. Snapshotted white on a
/// black capsule to approximate the on-face line.
struct InlineComplicationSnapshotTests {
    @MainActor @Test func inlineComplicationVariants() {
        for (name, model) in Self.variants {
            assertSnapshot(
                of: face(model),
                layout: .fixed(width: 220, height: 60),
                traits: .init(userInterfaceStyle: .dark),
                named: name
            )
        }
    }

    private func face(_ model: InlineComplicationRenderModel) -> some View {
        InlineComplicationContentView(model: model)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
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
