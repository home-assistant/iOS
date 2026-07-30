import HAWatchComplications
import Shared
import SwiftUI

/// iPhone preview of the inline complication: a single capsule line of name / value joined with " - ".
/// Inline has no icon or custom colors (watchOS renders it in the face tint). Renders through the
/// shared `InlineComplicationContentView`, so it can't drift from the on-watch rendering.
struct InlineComplicationPreview: View {
    let context: ComplicationPreviewContext

    var body: some View {
        // The whole line is the title slot's formula ("{name} - {value}" by default), matching the
        // watch's inline rendering.
        InlineComplicationContentView(model: InlineComplicationRenderModel(
            text: context.showsName ? context
                .titleText : ""
        ))
        .font(.system(size: 15))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

#if DEBUG
#Preview {
    InlineComplicationPreview(context: .preview(.inline, gauge: false))
        .padding()
}
#endif
