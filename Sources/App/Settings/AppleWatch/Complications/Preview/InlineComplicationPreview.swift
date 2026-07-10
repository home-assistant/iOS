import Shared
import SwiftUI

/// iPhone preview of the inline complication: a single capsule line of name / value joined with " - ".
/// Inline has no icon or custom colors (watchOS renders it in the face tint).
struct InlineComplicationPreview: View {
    let context: ComplicationPreviewContext

    var body: some View {
        Text(
            [context.showsName ? context.name : "", context.showsValue ? context.value : ""]
                .filter { !$0.isEmpty }
                .joined(separator: " - ")
        )
        .font(.system(size: 15))
        .lineLimit(1)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black))
    }
}
