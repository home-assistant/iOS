import HAWatchComplications
import Shared
import SwiftUI

/// iPhone preview of the circular complication. Renders through the shared
/// `CircularComplicationContentView` (the exact same view the watch uses), mapping the editor's
/// `ComplicationRenderContext` into the shared render model — so the preview can't drift from the
/// on-watch rendering.
struct CircularComplicationPreview: View {
    let context: ComplicationRenderContext

    var body: some View {
        CircularComplicationContentView(model: renderModel)
            .frame(width: 100, height: 100)
            .environment(\.colorScheme, .dark)
    }

    private var renderModel: CircularComplicationRenderModel {
        CircularComplicationRenderModel(
            iconImage: context.iconImage,
            showsIcon: context.iconImage != nil,
            valueText: context.valueText,
            showsValue: context.showsValue,
            title: context.titleText,
            showsName: context.showsName,
            fraction: context.showsGauge ? context.fraction : nil,
            isCapacityGauge: context.gaugeStyle == .capacity,
            minLabel: context.showsMin ? context.range.map { context.label($0.min) } : nil,
            maxLabel: context.showsMax ? context.range.map { context.label($0.max) } : nil,
            tint: context.tint,
            textColor: context.textColor
        )
    }
}

#if DEBUG
#Preview {
    CircularComplicationPreview(context: .preview(.circular))
        .padding()
}
#endif
