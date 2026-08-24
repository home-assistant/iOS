import SFSafeSymbols
import Shared
import SwiftUI

/// The illustration every migration screen leads with.
///
/// One component so the symbol lands at the same size, weight and position on all of them: the
/// screens are shown back to back as the user moves through the flow, and an illustration that
/// shifts or resizes between them makes the whole sequence look like it jumps.
///
/// Deliberately static. `CheckmarkDrawOnView`'s `.drawOn` effect starts undrawn, so anything that
/// captures the screen — snapshot tests included — catches it mid-animation; the step list is where
/// this flow does its animating.
struct AppMigrationIllustration: View {
    let symbol: SFSymbol
    var tint: Color = .haPrimary

    /// A square footprint every screen reserves, whatever the symbol's own proportions. Aspect-fit
    /// inside it means a wide symbol (`tray.and.arrow.up.fill`) scales down to fit the width rather
    /// than growing past a tall one (`arrow.up.forward.app`), so all of them occupy the same box and
    /// the flow does not shift as the user moves between screens.
    private static let size: CGFloat = 115

    var body: some View {
        Image(systemSymbol: symbol)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: Self.size, height: Self.size)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        AppMigrationIllustration(symbol: .arrowUpForwardApp)
        AppMigrationIllustration(symbol: .checkmarkCircleFill)
        AppMigrationIllustration(symbol: .exclamationmarkTriangleFill, tint: .red)
    }
}
