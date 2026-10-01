#if os(iOS) && !targetEnvironment(macCatalyst)
import Shared
import SwiftUI

@available(iOS 17.2, *)
struct HAActivityProgressBar: View {
    let fraction: Double
    let fillColor: Color
    let trackColor: Color
    let height: CGFloat

    private var clampedFraction: Double {
        min(max(fraction, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = clampedFraction == 0 ? 0 : max(geometry.size.width * clampedFraction, height)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackColor)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                fillColor.opacity(0.9),
                                fillColor,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.LiveActivity.Accessibility.progress)
        .accessibilityValue(Text(HAActivityVisualStyle.accessibilityPercentString(for: clampedFraction)))
    }
}
#endif
