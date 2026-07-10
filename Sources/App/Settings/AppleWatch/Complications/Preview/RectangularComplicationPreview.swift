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
                if context.showsName {
                    Text(context.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(context.textColor)
                }
                if context.showsGauge, let fraction = context.fraction {
                    RectangularGauge(
                        fraction: fraction,
                        minLabel: context.showsMin ? context.range.map { context.label($0.min) } : nil,
                        maxLabel: context.showsMax ? context.range.map { context.label($0.max) } : nil,
                        valueLabel: context.showsValue && !context.value.isEmpty ? context.value : nil,
                        tint: context.tint
                    )
                } else if context.showsValue, !context.value.isEmpty {
                    Text(context.value)
                        .font(.system(size: 13))
                        .foregroundStyle(context.textColor.opacity(0.85))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 200)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black))
    }
}
