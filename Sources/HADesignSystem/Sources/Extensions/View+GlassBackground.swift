#if !os(watchOS)
import SFSafeSymbols
import SwiftUI

/// Backs a control floating over media, such as a camera stream, with Liquid Glass, falling back
/// to the regular material where Liquid Glass isn't available.
///
/// Frontend counterpart: none. The frontend draws its overlay controls on a scrim instead.
public extension View {
    /// - Parameters:
    ///   - shape: The shape the glass, or the material, is clipped to.
    ///   - tint: Tints the glass. Before iOS 26 it fills the shape instead of the material, so a
    ///     tinted control keeps its color.
    ///   - isInteractive: Whether the glass reacts to touches, which only makes sense on controls.
    func haGlassBackground(
        in shape: some Shape,
        tint: Color? = nil,
        isInteractive: Bool = true
    ) -> some View {
        modify { view in
            if #available(iOS 26.0, *) {
                view.glassEffect(.regular.tint(tint).interactive(isInteractive), in: shape)
            } else if let tint {
                view.background(tint, in: shape)
            } else {
                view.background(.regularMaterial, in: shape)
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.haPrimary, .orange], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .xmark)
                .frame(width: 44, height: 44)
                .haGlassBackground(in: Circle())
            Text("Front Door")
                .padding(.horizontal, DesignSystem.Spaces.two)
                .frame(height: 44)
                .haGlassBackground(in: Capsule())
            Text("Stop talking")
                .padding(.horizontal, DesignSystem.Spaces.two)
                .frame(height: 44)
                .haGlassBackground(in: Capsule(), tint: .orange)
        }
        .foregroundStyle(.white)
    }
    .preferredColorScheme(.dark)
}
#endif
