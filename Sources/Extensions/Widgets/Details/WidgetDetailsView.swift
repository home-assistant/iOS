import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetDetailsView: View {
    @Environment(\.widgetFamily) var family: WidgetFamily

    var entry: WidgetDetailsEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            createTextView(alignment: HorizontalAlignment.leading)
        case .systemSmall:
            createTextView(alignment: HorizontalAlignment.center)
        default:
            if entry.upperText != nil || entry.lowerText != nil {
                Text((entry.upperText ?? "") + (entry.lowerText ?? ""))
            } else {
                Text("Unknown details")
                    .redacted(reason: .placeholder)
            }
        }
    }

    func createTextView(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment) {
            if let upperText = entry.upperText {
                Text(upperText)
                    .fontWeight(.bold)
            } else {
                Text("Unknown upper")
                    .fontWeight(.bold)
                    .redacted(reason: .placeholder)
            }

            if let lowerText = entry.lowerText {
                Text(lowerText)
            } else {
                Text("Unknown lower")
                    .redacted(reason: .placeholder)
            }

            if let detailsText = entry.detailsText {
                Text(detailsText)
            }
        }
    }
}
