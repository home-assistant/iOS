@testable import HADesignSystem
import SwiftUI
import Testing

/// The frontend's `common/color/rgb.ts`. `HALabel` and `HAQRCode` both depend on these landing the
/// same way they do on the web — a chip tinted a given hex should pick the same text colour, and a
/// themed QR code should decide it is unscannable at the same point.
struct ColorContrastTests {
    @Test func blackOnWhiteIsTheMaximumRatio() {
        let ratio = ColorContrast.ratio(.black, .white)
        #expect(ratio != nil)
        #expect(abs((ratio ?? 0) - 21) < 0.01)
    }

    @Test func aColourAgainstItselfHasNoContrast() {
        let ratio = ColorContrast.ratio(.white, .white)
        #expect(abs((ratio ?? 0) - 1) < 0.001)
    }

    @Test func theRatioIsSymmetric() {
        #expect(ColorContrast.ratio(.black, .white) == ColorContrast.ratio(.white, .black))
    }

    @Test func luminanceRunsFromBlackToWhite() {
        #expect(ColorContrast.relativeLuminance(.black) == 0)
        #expect(abs((ColorContrast.relativeLuminance(.white) ?? 0) - 1) < 0.001)
    }

    /// Green weighs far more than blue in the luminance sum, which is why a saturated blue takes
    /// white text and a saturated green does not.
    @Test func greenReadsBrighterThanBlue() {
        let green = ColorContrast.relativeLuminance(.green) ?? 0
        let blue = ColorContrast.relativeLuminance(.blue) ?? 0
        #expect(green > blue)
    }

    @Test func lightBackgroundsTakeBlackText() {
        #expect(ColorContrast.contrastingForeground(on: .white) == .black)
        #expect(ColorContrast.contrastingForeground(on: .yellow) == .black)
    }

    @Test func darkBackgroundsTakeWhiteText() {
        #expect(ColorContrast.contrastingForeground(on: .black) == .white)
        #expect(ColorContrast.contrastingForeground(on: .haPrimary) == .white)
    }

    /// The cutoff is a luminance of 0.5, not a contrast ratio — the frontend's
    /// `getContrastedColorHex` switches there, and matching it is the whole point.
    @Test func theSwitchIsAtHalfLuminance() {
        let justUnder = Color(white: 0.72)
        let justOver = Color(white: 0.74)
        #expect((ColorContrast.relativeLuminance(justUnder) ?? 1) < 0.5)
        #expect((ColorContrast.relativeLuminance(justOver) ?? 0) > 0.5)
        #expect(ColorContrast.contrastingForeground(on: justUnder) == .white)
        #expect(ColorContrast.contrastingForeground(on: justOver) == .black)
    }

    /// `HAQRCode` redraws its foreground below this, so the threshold itself is worth pinning.
    @Test func theMinimumRatioIsTheWcagNonTextMinimum() {
        #expect(ColorContrast.minimumRatio == 3)
        #expect((ColorContrast.ratio(.white, .white) ?? 0) < ColorContrast.minimumRatio)
        #expect((ColorContrast.ratio(.black, .white) ?? 0) > ColorContrast.minimumRatio)
    }
}
