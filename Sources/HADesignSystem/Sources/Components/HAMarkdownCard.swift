#if !os(watchOS)
import SwiftUI

/// A card of formatted prose. The SwiftUI counterpart of the frontend's `hui-markdown-card`, which
/// is a `ha-card` wrapped around a `ha-markdown`.
///
/// The rendering is ``HAMarkdownText``, so this covers the same GFM block set the frontend does —
/// headings, lists, fenced code, quotes, rules and tables — not just inline emphasis.
public struct HAMarkdownCard: View {
    private let title: String?
    private let content: String

    public init(title: String? = nil, content: String) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        HACard(header: title) {
            HAMarkdownText(content)
                .padding(DesignSystem.Spaces.two)
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAMarkdownCard(
            title: "Welcome",
            content: "The **kitchen** light is on and the _hallway_ is off. Check `sensor.power`."
        )
        HAMarkdownCard(
            title: "Today",
            content: """
            ## Chores

            - [x] Coffee
            - [ ] Water the plants

            > The garage has been open for 2 hours.
            """
        )
        HAMarkdownCard(content: "No title, just a line of prose.")
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAMarkdownCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-markdown-card" }
}

#endif
