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
        .accessibilityHint(Text(L10n.Widgets.Energy.refreshTitle))
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyRefreshButton(date: Date())
        .padding()
        .background(WidgetEnergyStyle.background)
}
