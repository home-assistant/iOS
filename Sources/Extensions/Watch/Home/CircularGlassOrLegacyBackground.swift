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
}

#endif
