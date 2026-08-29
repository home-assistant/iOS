#if !os(watchOS)
import SwiftUI

/// A full-width header that separates groups of rows, drawn on a quiet neutral fill. The SwiftUI
/// counterpart of the frontend's `ha-section-title`.
public struct HASectionTitle: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(DesignSystem.Font.body.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spaces.three)
            .padding(.vertical, DesignSystem.Spaces.two)
            // `min-height: var(--ha-space-6)` in the frontend, so short titles still fill the strip.
            .frame(minHeight: DesignSystem.Spaces.six, alignment: .leading)
            .background(Color.haNeutralQuietFill)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(spacing: .zero) {
        HASectionTitle("Living room")
        Text("Ceiling light")
            .padding()
        HASectionTitle("Kitchen")
        Text("Coffee machine")
            .padding()
    }
}

extension HASectionTitle: FrontendComponent {
    public static var frontendComponentName: String { "ha-section-title" }
}

#endif
