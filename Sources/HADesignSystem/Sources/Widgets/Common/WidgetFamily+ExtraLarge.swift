#if !os(watchOS)
import WidgetKit

public extension WidgetFamily {
    /// The extra-large families the running system offers: iOS 27 added a portrait one next to the
    /// landscape family, so a widget that fits one fits the other and has to offer both.
    static var extraLarges: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemExtraLarge]
        if #available(iOS 27.0, *) {
            families.append(.systemExtraLargePortrait)
        }
        return families
    }
}
#endif
