#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// A compact header that names the card below it: a headline on a translucent capsule, set in from
/// the card's leading edge. An optional symbol and tint let the header carry meaning (what comes
/// along, what needs doing again) without a full-width strip.
///
/// Frontend counterpart: none. The frontend labels groups with `ha-section-title`, a full-width bar;
/// this is the companion app's own lighter header for cards floating on an onboarding page.
public struct HASectionPill: View {
    private let title: String
    private let icon: SFSymbol?
    private let tint: Color

    /// - Parameters:
    ///   - icon: Drawn before the title, in the same tint.
    ///   - tint: Colors the text and symbol; the capsule itself stays neutral.
    public init(_ title: String, icon: SFSymbol? = nil, tint: Color = .secondary) {
        self.title = title
        self.icon = icon
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            if let icon {
                Image(systemSymbol: icon)
            }
            Text(title)
        }
        .font(DesignSystem.Font.headline)
        .foregroundStyle(tint)
        .padding(.vertical, DesignSystem.Spaces.one)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .padding(.leading, DesignSystem.Spaces.one)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HASectionPill("Next steps")
        CardView {
            Text("Add your widgets again")
        }
        HASectionPill("Comes with you", icon: .checkmarkCircleFill, tint: .haSuccessColor)
        CardView {
            Text("Servers and sign-ins")
        }
    }
    .padding()
}

#endif
