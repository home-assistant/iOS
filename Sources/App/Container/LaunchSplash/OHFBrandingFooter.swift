import SwiftUI

/// The "A PROJECT FROM THE" caption over the Open Home Foundation wordmark, as laid out at the bottom
/// of `LaunchScreen.storyboard`. Shared by the launch splash overlay and the first stand-by screen of a
/// cold launch so the branding stays put across the splash → stand-by hand-off.
struct OHFBrandingFooter: View {
    /// Mirrors the OHF logo constraints in `LaunchScreen.storyboard`.
    static let logoSize = CGSize(width: 220, height: 25)
    /// Mirrors the storyboard's OHF-logo-bottom-to-safe-area constraint.
    static let bottomPadding: CGFloat = 32
    /// Mirrors the "A PROJECT FROM THE" caption above the OHF logo in `LaunchScreen.storyboard`.
    private static let captionFontSize: CGFloat = 13

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "A PROJECT FROM THE")
                .font(.system(size: Self.captionFontSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Image(.ohfInline)
                .resizable()
                .scaledToFit()
                .frame(width: Self.logoSize.width, height: Self.logoSize.height)
        }
    }
}

#Preview {
    OHFBrandingFooter()
}
