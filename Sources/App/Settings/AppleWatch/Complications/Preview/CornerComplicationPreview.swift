import Shared
import SwiftUI

/// iPhone preview of the corner complication: content tucked toward the bottom of the face with a
/// linear gauge, approximating the on-watch curved corner rendering.
struct CornerComplicationPreview: View {
    let context: ComplicationPreviewContext

    var body: some View {
        ZStack {
            Circle().fill(Color.black)
            VStack(spacing: 2) {
                Spacer()
                context.iconImage?
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                if context.showsValue, !context.value.isEmpty {
                    Text(context.value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(context.textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                if context.showsGauge, let fraction = context.fraction {
                    Gauge(value: fraction) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(context.tint)
                        .frame(width: 66)
                }
            }
            .padding(12)
        }
        .frame(width: 100, height: 100)
        .environment(\.colorScheme, .dark)
    }
}

#if DEBUG
#Preview {
    CornerComplicationPreview(context: .preview(.corner))
        .padding()
}
#endif
