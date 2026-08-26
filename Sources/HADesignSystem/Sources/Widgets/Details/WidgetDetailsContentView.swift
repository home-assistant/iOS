#if !os(watchOS)
import SwiftUI
import WidgetKit

/// The lock screen "details" widget: up to three lines on the rectangular accessory, and the first
/// two run together on anything narrower.
///
/// A line the entry hasn't resolved yet is drawn redacted rather than left out, so the widget keeps
/// its shape while a template renders.
public struct WidgetDetailsContentView: View {
    private let upperText: String?
    private let lowerText: String?
    private let detailsText: String?
    private let family: WidgetFamily

    public init(
        upperText: String?,
        lowerText: String?,
        detailsText: String?,
        family: WidgetFamily
    ) {
        self.upperText = upperText
        self.lowerText = lowerText
        self.detailsText = detailsText
        self.family = family
    }

    public var body: some View {
        if family == .accessoryRectangular {
            VStack(alignment: .leading) {
                if let upperText {
                    Text(upperText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fontWeight(.bold)
                } else {
                    Text(verbatim: "Unknown upper")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fontWeight(.bold)
                        .redacted(reason: .placeholder)
                }
                if let lowerText {
                    Text(lowerText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(verbatim: "Unknown lower")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .redacted(reason: .placeholder)
                }
                if let detailsText {
                    Text(detailsText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            if upperText != nil || lowerText != nil {
                Text((upperText ?? "") + (lowerText ?? ""))
            } else {
                Text(verbatim: "Unknown details")
                    .redacted(reason: .placeholder)
            }
        }
    }
}

#Preview {
    WidgetDetailsContentView(
        upperText: "Living room",
        lowerText: "21.4 °C",
        detailsText: "Humidity 48%",
        family: .accessoryRectangular
    )
    .padding()
}
#endif
