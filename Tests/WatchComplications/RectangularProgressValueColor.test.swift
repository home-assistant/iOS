import HAWatchComplications
import SwiftUI
import Testing

/// The rectangular complication draws its value inside the progress bar's thumb, not in the text
/// stack, so that one slot resolves its color separately — these pin that it still honors the color
/// the user picked for the complication's text, and only falls back to the automatic contrast shade
/// when there is none.
struct RectangularProgressValueColorTests {
    @Test("A configured text color wins over the automatic contrast shade")
    func configuredColorWins() {
        #expect(RectangularProgressView.valueLabelColor(configured: .yellow, tint: .green) == .yellow)
        // Even when the automatic choice would have picked the same shade the user did.
        #expect(RectangularProgressView.valueLabelColor(configured: .white, tint: .green) == .white)
    }

    @Test("Without a configured color, the value reads against the tint")
    func automaticContrast() {
        #expect(RectangularProgressView.valueLabelColor(configured: nil, tint: .black) == .white)
        #expect(RectangularProgressView.valueLabelColor(configured: nil, tint: .white) == .black)
        // The Home Assistant default tint is dark enough for white.
        #expect(RectangularProgressView.valueLabelColor(configured: nil, tint: .complicationDefaultTint) == .white)
    }
}
