#if os(watchOS)
import Shared
import SwiftUI

private struct CircularGlassOrLegacyBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(watchOS 26.0, *) {
                content
                    .frame(width: 30, height: 30)
                    .padding(DesignSystem.Spaces.half)
                    .glassEffect(.clear.interactive(), in: .circle)
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
    func circularGlassOrLegacyBackground() -> some View {
        modifier(CircularGlassOrLegacyBackgroundModifier())
    }
}

#endif
