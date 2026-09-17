import Shared
import WidgetKit

/// The widget sizes the Areas widget offers. Every one of them is snapshot tested.
enum WidgetAreasSupportedFamilies {
    static var families: [WidgetFamily] {
        [.systemSmall, .systemMedium, .systemLarge] + WidgetFamily.extraLarges
    }
}
