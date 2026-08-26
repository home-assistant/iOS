import Shared
import SwiftUI

/// The time the entry was last refreshed, preceded by a small reload glyph, mirroring the energy
/// widget. The pair is one control: tapping either part reloads the widget's timeline.
@available(iOS 17, *)
struct WidgetRefreshButton: View {
    let kind: WidgetsKind
    let date: Date

    private var refreshIntent: WidgetRefreshAppIntent {
        let intent = WidgetRefreshAppIntent()
        intent.widgetKind = kind.rawValue
        return intent
    }

    var body: some View {
        Button(intent: refreshIntent) {
            WidgetRefreshLabel(date: date)
        }
        .buttonStyle(.plain)
        // The visible text is a timestamp, so name the action explicitly and leave the time as the
        // value — otherwise VoiceOver announces a bare time with no hint of what tapping does.
        .accessibilityLabel(Text(L10n.Widgets.refreshTitle))
        .accessibilityValue(Text(date, style: .time))
    }
}

@available(iOS 17, *)
#Preview {
    WidgetRefreshButton(kind: .custom, date: Date())
        .padding()
}
