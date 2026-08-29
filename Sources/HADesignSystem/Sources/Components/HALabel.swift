#if !os(watchOS)
import HAIconic
import SwiftUI

/// A rounded chip naming something the user has organised — a label, a category, a tag. The SwiftUI
/// counterpart of the frontend's `ha-label`.
///
/// Given a `color`, the chip fills with it and the text flips to black or white so it stays legible,
/// as the frontend does with `getContrastedColorHex`. Without one it falls back to a wash of the
/// text colour.
public struct HALabel: View {
    private let text: String
    private let icon: MaterialDesignIcons?
    private let color: Color?
    private let dense: Bool

    /// - Parameter dense: The compact form the frontend reflects as the `dense` attribute: half the
    ///   height, tighter padding and a smaller radius, for chips inside a table row.
    public init(
        _ text: String,
        icon: MaterialDesignIcons? = nil,
        color: Color? = nil,
        dense: Bool = false
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.dense = dense
    }

    private var foregroundColor: Color {
        guard let color else { return Color(uiColor: .label) }
        return color.contrastingForeground
    }

    /// `--ha-border-radius-xl` normally, `--ha-border-radius-md` when dense.
    private var cornerRadius: CGFloat {
        dense ? DesignSystem.CornerRadius.one : DesignSystem.CornerRadius.two
    }

    public var body: some View {
        HStack(spacing: dense ? DesignSystem.Spaces.half : DesignSystem.Spaces.one) {
            if let icon {
                MaterialDesignIconsImage(icon: icon, size: 12)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, dense ? DesignSystem.Spaces.oneAndHalf : DesignSystem.Spaces.two)
        .frame(height: dense ? 20 : 32)
        .background(color ?? Color(uiColor: .label).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            // `strokeBorder`, not `stroke`: a centred stroke would put half its width outside the
            // fill, which reads as a fringe against the surface behind the chip.
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.haDivider, lineWidth: DesignSystem.Border.Width.default)
        )
    }
}

private extension Color {
    /// Black or white, whichever reads better on this colour, so a chip tinted a given hex lands on
    /// the same choice as the frontend's `getContrastedColorHex`. Shared with ``HAQRCode``, which
    /// needs the same call for the same reason.
    var contrastingForeground: Color {
        ColorContrast.contrastingForeground(on: self)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HALabel("Untinted")
        HALabel("With icon", icon: .homeOutlineIcon)
        HALabel("Tinted dark", color: .haPrimary)
        HALabel("Tinted light", color: .yellow)
        HALabel("Dense", dense: true)
        HALabel("Dense with icon", icon: .homeOutlineIcon, color: .haSuccessColor, dense: true)
    }
    .padding()
}

extension HALabel: FrontendComponent {
    public static var frontendComponentName: String { "ha-label" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
