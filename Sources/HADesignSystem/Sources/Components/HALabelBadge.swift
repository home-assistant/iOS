#if !os(watchOS)
import SwiftUI

/// A coloured ring — optionally filled with a picture — with a pill label straddling its lower edge
/// and a caption beneath. The SwiftUI counterpart of the frontend's `ha-label-badge`.
///
/// The label overlaps the ring rather than sitting under it, which is what makes the badge read as
/// one object; the description below belongs to the badge but is not part of it.
public struct HALabelBadge: View {
    private let label: String?
    private let description: String?
    private let image: Image?
    private let color: Color

    /// - Parameter image: Fills the ring. The package fetches nothing, so the caller hands in a
    ///   resolved `Image`, as ``HASelectBox`` and ``HAPictureCard`` do.
    public init(
        label: String? = nil,
        description: String? = nil,
        image: Image? = nil,
        color: Color = .haSuccessColor
    ) {
        self.label = label
        self.description = description
        self.image = image
        self.color = color
    }

    private static let size: CGFloat = 64

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.half) {
            ZStack(alignment: .bottom) {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .background(
                        Circle().fill(Color.haCardBackground)
                    )
                    .overlay {
                        if let image {
                            image
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                                .padding(2)
                        }
                    }
                    .frame(width: Self.size, height: Self.size)
                if let label {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, DesignSystem.Spaces.one)
                        .padding(.vertical, DesignSystem.Spaces.micro)
                        .background(color)
                        .clipShape(Capsule())
                        // Straddles the ring's lower edge rather than clearing it.
                        .frame(maxWidth: Self.size + DesignSystem.Spaces.one)
                        .offset(y: DesignSystem.Spaces.one)
                }
            }
            // Room for the label hanging below the ring, so the caption is not pushed into it.
            .padding(.bottom, label == nil ? .zero : DesignSystem.Spaces.oneAndHalf)
            if let description {
                Text(description)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: Self.size + DesignSystem.Spaces.two)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
        HALabelBadge(label: "Label")
        HALabelBadge(label: "Label", description: "Description")
        HALabelBadge(description: "Description", color: .haPrimary)
        HALabelBadge(label: "Big label that truncates", description: "Description", color: .haWarningColor)
    }
    .padding()
}

extension HALabelBadge: FrontendComponent {
    public static var frontendComponentName: String { "ha-label-badge" }
}

#endif
