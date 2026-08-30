#if !os(watchOS)
import SwiftUI

/// The surface every dashboard card sits on: the card background, a hairline border and a 12pt
/// radius. The SwiftUI counterpart of the frontend's `ha-card`.
///
/// Distinct from ``CardView``, which predates it and is what the app's settings screens use — that
/// one has an 8pt radius, a different border colour and no background of its own. They should be
/// folded together once the dashboard cards land; until then this is the one that matches the
/// frontend, and `CardView` is left alone rather than restyled under its existing call sites.
public struct HACard<Content: View>: View {
    private let header: String?
    private let raised: Bool
    private let content: Content

    /// - Parameter raised: Drops the border for a shadow, the frontend's `raised` attribute.
    public init(header: String? = nil, raised: Bool = false, @ViewBuilder content: () -> Content) {
        self.header = header
        self.raised = raised
        self.content = content()
    }

    private static var cornerRadius: CGFloat { DesignSystem.CornerRadius.oneAndHalf }

    public var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            if let header {
                Text(header)
                    .font(DesignSystem.Font.title2)
                    .padding(.horizontal, DesignSystem.Spaces.two)
                    .padding(.top, DesignSystem.Spaces.oneAndHalf)
                    .padding(.bottom, DesignSystem.Spaces.two)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.haCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .overlay {
            if !raised {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(Color.haDivider, lineWidth: DesignSystem.Border.Width.default)
            }
        }
        .shadow(
            color: raised ? .black.opacity(0.2) : .clear,
            radius: raised ? 3 : 0,
            y: raised ? 1 : 0
        )
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HACard {
            Text("Card content").padding()
        }
        HACard(header: "With a header") {
            Text("Card content").padding()
        }
        HACard(raised: true) {
            Text("Raised").padding()
        }
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HACard: FrontendComponent {
    public static var frontendComponentName: String { "ha-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
