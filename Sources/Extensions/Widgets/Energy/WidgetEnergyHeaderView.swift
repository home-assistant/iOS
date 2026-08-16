import Foundation
import SwiftUI

/// Header shared by the home screen Energy layouts: the summarised period on the leading edge and the
/// reload button plus the time the entry was refreshed on the trailing edge. Both ends reload the
/// widget when tapped.
@available(iOS 17, *)
struct WidgetEnergyHeaderView: View {
    let period: WidgetEnergyPeriod
    let date: Date

    var body: some View {
        HStack {
            WidgetEnergyPeriodButton(period: period, font: .system(size: 12, weight: .semibold))
            Spacer()
            WidgetEnergyRefreshButton(date: date)
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
