import Shared
import SwiftUI

/// iPhone preview of the rectangular complication: optional icon + name, plus the progress bar (value
/// thumb + min/max) when a gauge value exists, else the value as text.
struct RectangularComplicationPreview: View {
    let context: ComplicationPreviewContext

    var body: some View {
        HStack(spacing: 8) {
            context.iconImage?
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                if context.showsName, !context.titleText.isEmpty {
                    Text(context.titleText)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(context.textColor)
                }
                if context.showsSubtitle, !context.subtitleText.isEmpty {
                    Text(context.subtitleText)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundStyle(context.textColor.opacity(0.8))
                }
                if context.showsGauge, let fraction = context.fraction {
                    RectangularGauge(
                        fraction: fraction,
                        minLabel: context.showsMin ? context.range.map { context.label($0.min) } : nil,
                        maxLabel: context.showsMax ? context.range.map { context.label($0.max) } : nil,
                        valueLabel: context.showsValue && !context.valueText.isEmpty ? context.valueText : nil,
                        tint: context.tint
                    )
                } else if context.showsValue, !context.valueText.isEmpty {
                    Text(context.valueText)
                        .font(.system(size: 13))
                        .foregroundStyle(context.textColor.opacity(0.85))
                        .lineLimit(1)
                }
                if context.showsBottomText, !context.bottomText.isEmpty {
                    Text(context.bottomText)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundStyle(context.textColor.opacity(0.8))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 200)
    }
}

#if DEBUG
#Preview {
    RectangularComplicationPreview(context: .preview(.rectangular))
        .padding()
}
#endif
