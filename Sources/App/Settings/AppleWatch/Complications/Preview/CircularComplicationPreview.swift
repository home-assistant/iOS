import Shared
import SwiftUI

/// iPhone preview of the circular complication: the real WidgetKit accessory gauge styles (open arc
/// with min/max labels, or a full capacity ring) around the icon / value / name, else just the center.
struct CircularComplicationPreview: View {
    let context: ComplicationPreviewContext

    var body: some View {
        ZStack {
            Circle().fill(Color.black)
            Group {
                if context.showsGauge, let fraction = context.fraction {
                    switch context.gaugeStyle {
                    case .open:
                        Gauge(value: fraction) {
                            EmptyView()
                        } currentValueLabel: {
                            center
                        } minimumValueLabel: {
                            Text(verbatim: (context.showsMin ? context.range.map { context.label($0.min) } : nil) ?? "")
                        } maximumValueLabel: {
                            Text(verbatim: (context.showsMax ? context.range.map { context.label($0.max) } : nil) ?? "")
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(context.tint)
                    case .capacity:
                        Gauge(value: fraction) {
                            EmptyView()
                        } currentValueLabel: {
                            center
                        }
                        .gaugeStyle(.accessoryCircularCapacity)
                        .tint(context.tint)
                    }
                } else {
                    center
                }
            }
            .padding(12)
        }
        .frame(width: 100, height: 100)
        .environment(\.colorScheme, .dark)
    }

    /// Icon / value / name shown in the middle, each per its toggle.
    private var center: some View {
        VStack(spacing: 0) {
            context.iconImage?
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            if context.showsValue, !context.value.isEmpty {
                Text(context.value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(context.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            }
            if context.showsName, !context.name.isEmpty {
                Text(context.name)
                    .font(.system(size: 9))
                    .foregroundStyle(context.textColor.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

#if DEBUG
#Preview {
    CircularComplicationPreview(context: .preview(.circular))
        .padding()
}
#endif
