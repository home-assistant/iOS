import Shared
import SwiftUI

/// The summarised period, which doubles as a reload control so the whole header behaves the same way
/// as the reload button sitting next to the timestamp.
@available(iOS 17, *)
struct WidgetEnergyPeriodButton: View {
    let period: WidgetEnergyPeriod
    var font: Font = .system(size: 11, weight: .semibold)

    var body: some View {
        Button(intent: WidgetEnergyRefreshAppIntent()) {
            Text(period.displayTitle)
                .font(font)
                .foregroundStyle(WidgetEnergyStyle.secondaryText)
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(L10n.Widgets.Energy.refreshTitle))
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyPeriodButton(period: .thisWeek)
        .padding()
        .background(WidgetEnergyStyle.background)
}
