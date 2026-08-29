#if !os(watchOS)
import SwiftUI

/// A picture filling a card, optionally captioned with a name and a state. Covers the frontend's
/// `hui-picture-card` and `hui-picture-entity-card`, which differ only in whether they caption it.
///
/// Takes a resolved `Image` rather than a URL: the package fetches nothing, the same arrangement
/// ``HASelectBox`` uses.
public struct HAPictureCard<Footer: View>: View {
    private let image: Image
    private let aspectRatio: CGFloat
    private let name: String?
    private let state: String?
    private let onTap: (() -> Void)?
    private let footer: Footer

    /// - Parameters:
    ///   - aspectRatio: The frontend takes `aspect_ratio` as a string; here it is the ratio itself.
    ///   - footer: Content laid over the bottom of the picture, e.g. a row of glance chips.
    public init(
        image: Image,
        aspectRatio: CGFloat = 16 / 9,
        name: String? = nil,
        state: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder footer: () -> Footer
    ) {
        self.image = image
        self.aspectRatio = aspectRatio
        self.name = name
        self.state = state
        self.onTap = onTap
        self.footer = footer()
    }

    public var body: some View {
        HACard {
            image
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottom) {
                    if name != nil || state != nil {
                        HStack {
                            if let name {
                                Text(name)
                            }
                            Spacer(minLength: DesignSystem.Spaces.one)
                            if let state {
                                Text(state)
                            }
                        }
                        .font(DesignSystem.Font.body)
                        .foregroundStyle(.white)
                        .padding(DesignSystem.Spaces.one)
                        .frame(maxWidth: .infinity)
                        // The caption sits on the picture, so it carries its own scrim rather than
                        // trusting whatever happens to be behind it.
                        .background(.black.opacity(0.4))
                    }
                }
                // The picture and its caption are one element and one tap target; the footer is
                // not. It holds the glance buttons, and combining them in would collapse every
                // entity chip into the card and leave none of them focusable.
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(optional: name)
                .overlay(alignment: .bottom) { footer }
        }
    }
}

public extension HAPictureCard where Footer == EmptyView {
    /// A picture with nothing laid over it beyond its caption.
    init(
        image: Image,
        aspectRatio: CGFloat = 16 / 9,
        name: String? = nil,
        state: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            image: image,
            aspectRatio: aspectRatio,
            name: name,
            state: state,
            onTap: onTap,
            footer: { EmptyView() }
        )
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAPictureCard(image: Image(systemSymbol: .photo))
        HAPictureCard(image: Image(systemSymbol: .photo), name: "Front door", state: "Closed")
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAPictureCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-picture-card" }
}

#endif
