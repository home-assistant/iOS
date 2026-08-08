import Shared
import SwiftUI

/// Header shared by the home screen Energy layouts: the summarised period on the leading edge and
/// the time the entry was refreshed on the trailing edge.
@available(iOS 17, *)
struct WidgetEnergyHeaderView: View {
    let period: WidgetEnergyPeriod
    let date: Date

    var body: some View {
        HStack {
            Text(period.displayTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetEnergyStyle.secondaryText)
            Spacer()
            Text(date, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(WidgetEnergyStyle.secondaryText)
        }
        .lineLimit(1)
    }
}

@available(iOS 17, *)
#Preview {
    WidgetEnergyHeaderView(period: .thisWeek, date: Date())
        .padding()
        .background(WidgetEnergyStyle.background)
}
