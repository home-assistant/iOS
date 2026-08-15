import SFSafeSymbols
import Shared
import SwiftUI

/// The time the entry was last refreshed, preceded by a small reload glyph. The pair is one control:
/// tapping the glyph or the timestamp reloads the widget's timeline.
@available(iOS 17, *)
struct WidgetEnergyRefreshButton: View {
    let date: Date
    var font: Font = .system(size: 11)

    var body: some View {
        Button(intent: WidgetEnergyRefreshAppIntent()) {
            HStack(spacing: DesignSystem.Spaces.micro) {
                Image(systemSymbol: .arrowClockwise)
                    .font(.system(size: 9, weight: .semibold))
                Text(date, style: .time)
                    .font(font)
            }
            .foregroundStyle(WidgetEnergyStyle.secondaryText)
            .lineLimit(1)
        }
        .buttonStyle(.plain)
        // The visible text is a timestamp, so name the action explicitly and leave the time as the
        // value — otherwise VoiceOver announces a bare time with no hint of what tapping does.
        .accessibilityLabel(Text(L10n.Widgets.Energy.refreshTitle))
        .accessibilityValue(Text(date, style: .time))
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyRefreshButton(date: Date())
        .padding()
        .background(WidgetEnergyStyle.background)
}
