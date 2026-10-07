#if !os(watchOS)
import SwiftUI

/// A tile's two lines of text: what it is, and what it is doing. The SwiftUI counterpart of the
/// frontend's `ha-tile-info`.
///
/// Both lines truncate rather than wrap. A tile sits in a grid beside its neighbours, so a name
/// growing to two lines would push the whole row taller.
public struct HATileInfo: View {
    private let primary: String
    private let secondary: String?
    private let isSecondaryLoading: Bool
    private let alignment: HorizontalAlignment

    /// - Parameters:
    ///   - isSecondaryLoading: Draws a placeholder bar in place of the second line, for state that
    ///     has not arrived yet — the frontend's `secondary-loading`.
    ///   - alignment: Centred for a vertical tile, leading otherwise.
    public init(
        primary: String,
        secondary: String? = nil,
        isSecondaryLoading: Bool = false,
        alignment: HorizontalAlignment = .leading
    ) {
        self.primary = primary
        self.secondary = secondary
        self.isSecondaryLoading = isSecondaryLoading
        self.alignment = alignment
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: .zero) {
            Text(primary)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
            if isSecondaryLoading {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half)
                    .fill(Color.haDisabled.opacity(0.3))
                    .frame(width: 100, height: 12)
            } else if let secondary {
                Text(secondary)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HATileInfo(primary: "Ceiling light", secondary: "On")
        HATileInfo(primary: "Ceiling light")
        HATileInfo(primary: "Ceiling light", isSecondaryLoading: true)
        HATileInfo(
            primary: "A name far too long to fit on one line of a tile",
            secondary: "And a state that is also much too long"
        )
        HATileInfo(primary: "Centred", secondary: "For a vertical tile", alignment: .center)
    }
    .frame(width: 200)
    .padding()
}

extension HATileInfo: FrontendComponent {
    public static var frontendComponentName: String { "ha-tile-info" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
