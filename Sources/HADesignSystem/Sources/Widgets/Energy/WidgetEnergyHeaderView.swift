#if !os(watchOS)
import Foundation
import SwiftUI

/// Header shared by the home screen Energy layouts: the summarised period on the leading edge and the
/// reload button plus the time the entry was refreshed on the trailing edge. Both ends reload the
/// widget when tapped, which is why both are handed back to the caller to wrap.
public struct WidgetEnergyHeaderView: View {
    /// Wraps a rendered label in the control that runs it.
    public typealias ControlContent = (AnyView) -> AnyView

    private let periodTitle: String
    private let date: Date
    private let periodControl: ControlContent
    private let refreshControl: ControlContent

    public init(
        periodTitle: String,
        date: Date,
        periodControl: @escaping ControlContent = { $0 },
        refreshControl: @escaping ControlContent = { $0 }
    ) {
        self.periodTitle = periodTitle
        self.date = date
        self.periodControl = periodControl
        self.refreshControl = refreshControl
    }

    public var body: some View {
        HStack {
            periodControl(AnyView(WidgetEnergyPeriodLabel(
                title: periodTitle,
                font: .system(size: 12, weight: .semibold)
            )))
            Spacer()
            refreshControl(AnyView(WidgetRefreshLabel(date: date, color: WidgetEnergyPalette.secondaryText)))
        }
        .lineLimit(1)
    }
}

#Preview {
    WidgetEnergyHeaderView(periodTitle: "This week", date: Date(timeIntervalSince1970: 1_700_000_000))
        .padding()
        .background(WidgetEnergyPalette.background)
}
#endif
