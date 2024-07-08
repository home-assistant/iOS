import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetDetailsView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    var entry: WidgetDetailsEntry

    var body: some View {
        if family == .accessoryRectangular {
            VStack(alignment: .leading) {
                if entry.upperText != nil {
                    Text(entry.upperText!)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fontWeight(.bold)
                } else {
                    Text("Unknown upper")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fontWeight(.bold)
                        .redacted(reason: .placeholder)
                }
                if entry.lowerText != nil {
                    Text(entry.lowerText!)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Unknown lower")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .redacted(reason: .placeholder)
                }
                if entry.detailsText != nil {
                    Text(entry.detailsText!)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            if entry.upperText != nil || entry.lowerText != nil {
                Text((entry.upperText ?? "") + (entry.lowerText ?? ""))
            } else {
                Text("Unknown details")
                    .redacted(reason: .placeholder)
            }
        }
    }
}
