#if !os(watchOS)
import SwiftUI

/// A centred hint under a screen's content: a lightbulb, the bold word "Tip", then the advice. The
/// SwiftUI counterpart of the frontend's `ha-tip`.
///
/// The prefix comes from ``HADesignSystemEnvironment`` rather than `L10n`, because the package
/// cannot import `Shared`.
public struct HATipView: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    /// One concatenated `Text`, not an `HStack`: the rendered `ha-tip` flows the lamp, the prefix and
    /// the advice as a single centred paragraph, so a long tip wraps across the full width. Laid out
    /// as a row, the advice would instead wrap inside a narrow column beside the prefix.
    private var paragraph: Text {
        let lamp = Text(MaterialDesignIconsImage.templateImage(icon: .lightbulbOutlineIcon, size: 18))
        let prefix = Text(HADesignSystemEnvironment.current.strings.tipPrefix).fontWeight(.medium)
        // `foregroundColor` rather than `foregroundStyle`: only the former returns `Text` on iOS 16,
        // and the concatenation below needs `Text` the whole way through.
        let advice = Text(text).foregroundColor(.secondary)
        return lamp + Text("  ") + prefix + Text(" ") + advice
    }

    public var body: some View {
        paragraph
            .font(DesignSystem.Font.body)
            .multilineTextAlignment(.center)
            // Without this the paragraph truncates instead of wrapping: text answers a short height
            // proposal by dropping to one line, and `sizeThatFits` offers exactly that.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel(Text("\(HADesignSystemEnvironment.current.strings.tipPrefix) \(text)"))
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.three) {
        HATipView("You can drag cards to reorder them.")
        HATipView("Long-press a tile to open its more-info dialog, where every attribute is listed.")
    }
    .padding()
}

extension HATipView: FrontendComponent {
    public static var frontendComponentName: String { "ha-tip" }
}

#endif
