#if !os(watchOS)
import SwiftUI

/// A rail of icon toggles sharing one quiet background, with the selected one marked by a filled
/// circle. The SwiftUI counterpart of the frontend's `ha-icon-button-group`.
///
/// The frontend slides a thumb between positions; here each ``HAIconButtonToggle`` draws its own
/// circle, since a shared thumb would have to animate between children and a snapshot could only
/// ever catch it mid-slide.
public struct HAIconButtonGroup<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spaces.half) {
            content
        }
        .padding(DesignSystem.Spaces.half)
        .background(Color.haDisabled.opacity(0.2))
        .clipShape(Capsule())
    }
}

#Preview {
    HAIconButtonGroup {
        HAIconButtonToggle(icon: .formatBoldIcon, label: "Bold", isSelected: .constant(true))
        HAIconButtonToggle(icon: .formatItalicIcon, label: "Italic", isSelected: .constant(false))
        HAIconButtonToggle(icon: .formatUnderlineIcon, label: "Underline", isSelected: .constant(false))
    }
    .padding()
}

extension HAIconButtonGroup: FrontendComponent {
    public static var frontendComponentName: String { "ha-icon-button-group" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
