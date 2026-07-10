import SwiftUI
import WidgetKit

/// Inline complication: a single line of name / value. Inline has no icon or custom colors (watchOS
/// renders it in the face's tint); the name and value are joined with " - ".
@available(watchOS 10.0, *)
struct InlineComplicationView: View {
    let complication: WatchWidgetComplicationSnapshot?
    let family: WidgetFamily

    var body: some View {
        if let complication {
            let text = inlineText(for: complication)
            Text(text.isEmpty ? WatchWidgetConstants.appName : text)
        } else {
            Text(WatchWidgetConstants.appName)
        }
    }

    private func inlineText(for complication: WatchWidgetComplicationSnapshot) -> String {
        guard complication.perFamily != nil else { return complication.inlineText }
        return [
            complication.showsName(for: family) ? complication.subtitle : "",
            complication.showsValue(for: family) ? complication.title : "",
        ].filter { !$0.isEmpty }.joined(separator: " - ")
    }
}

#if DEBUG
@available(watchOS 10.0, *)
#Preview {
    InlineComplicationView(complication: .previewSample(), family: .accessoryInline)
}
#endif
