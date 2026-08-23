import Shared
import SwiftUI

/// Caption over the Open Home Foundation wordmark. Shared by the launch splash overlay and the first
/// stand-by of a cold launch so branding stays put across the hand-off. `LaunchScreen.storyboard` omits
/// the caption — launch screens don't localize reliably — and this view supplies `L10n.OhfBranding.caption`.
struct OHFBrandingFooter: View {
    /// Mirrors the OHF logo constraints in `LaunchScreen.storyboard`.
    static let logoSize = CGSize(width: 220, height: 25)
    /// Mirrors the storyboard's OHF-logo-bottom-to-safe-area constraint.
    static let bottomPadding: CGFloat = 32
    private static let captionFontSize: CGFloat = 13

    var body: some View {
        VStack(spacing: 0) {
            Text(L10n.OhfBranding.caption)
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
