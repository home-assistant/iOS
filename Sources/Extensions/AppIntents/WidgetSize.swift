import AppIntents
import Foundation

@available(iOS 17.0, *)
public enum WidgetSize {
    static let size: [IntentWidgetFamily: IntentCollectionSize] = [
        .systemSmall: 2,
        .systemMedium: 4,
        .systemLarge: 10,
        .systemExtraLarge: 20,
        .accessoryInline: 1,
        .accessoryCorner: 1,
        .accessoryCircular: 1,
        .accessoryRectangular: 2,
    ]
}
