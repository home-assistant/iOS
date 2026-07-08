#if os(watchOS)
import Shared
import SwiftUI

private struct CircularGlassOrLegacyBackgroundModifier: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        Group {
            if #available(watchOS 26.0, *) {
                content
                    .frame(width: 30, height: 30)
                    .padding(DesignSystem.Spaces.half)
                    .glassEffect(.clear.interactive().tint(tint), in: .circle)
            } else {
                content
                    .padding(DesignSystem.Spaces.half)
                    .background(.black)
                    .clipShape(.circle)
            }
        }
    }
}

extension View {
    /// Applies a circular glass effect on watchOS 26+, otherwise falls back to padding + black background.
    func circularGlassOrLegacyBackground(tint: Color? = nil) -> some View {
        modifier(CircularGlassOrLegacyBackgroundModifier(tint: tint))
    }

    /// Full-width glass row style for the watch home items on watchOS 26: a rounded rectangle (not a
    /// capsule) spanning the row with no horizontal margin. Falls back to a rounded, optionally-tinted
    /// row background on older versions. Apply to the item's `Button`.
    @ViewBuilder
    func watchHomeItemRowStyle(tint: Color?) -> some View {
        modify { view in
            if #available(watchOS 26.0, *) {
                view
                    .buttonStyle(.plain)
                    .glassEffect(
                        .regular.tint(tint).interactive(),
                        in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous)
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: DesignSystem.Spaces.micro,
                        leading: .zero,
                        bottom: DesignSystem.Spaces.micro,
                        trailing: .zero
                    ))
            } else {
                view
                    .listRowBackground(
                        (tint ?? Color.gray.opacity(0.3))
                            .cornerRadius(DesignSystem.CornerRadius.two)
                    )
            }
        }
    }

    @ViewBuilder
    func watchHomeItemGridStyle(tint: Color?) -> some View {
        buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .modify { view in
                if #available(watchOS 26.0, *) {
                    view.glassEffect(
                        .regular.tint(tint).interactive(),
                        in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.two, style: .continuous)
                    )
                } else {
                    view.background(
                        (tint ?? Color.gray.opacity(0.3))
                            .cornerRadius(DesignSystem.CornerRadius.two)
                    )
                }
            }
    }
}

#endif
