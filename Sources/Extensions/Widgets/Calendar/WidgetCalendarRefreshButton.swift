import Foundation
import SFSafeSymbols
import Shared
import SwiftUI

/// The time the entry was last refreshed, preceded by a small reload glyph, mirroring the energy
/// widget. The pair is one control: tapping either part reloads the widget's timeline.
@available(iOS 17, *)
struct WidgetCalendarRefreshButton: View {
    let date: Date

    var body: some View {
        Button(intent: WidgetCalendarRefreshAppIntent()) {
            HStack(spacing: DesignSystem.Spaces.micro) {
                Image(systemSymbol: .arrowClockwise)
                    .font(.system(size: 9, weight: .semibold))
                Text(date, style: .time)
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .buttonStyle(.plain)
        // The visible text is a timestamp, so name the action explicitly and leave the time as the
        // value — otherwise VoiceOver announces a bare time with no hint of what tapping does.
        .accessibilityLabel(Text(L10n.Widgets.Calendar.refreshTitle))
        .accessibilityValue(Text(date, style: .time))
    }
}

@available(iOS 17, *)
#Preview {
    WidgetCalendarRefreshButton(date: Date())
        .padding()
}
