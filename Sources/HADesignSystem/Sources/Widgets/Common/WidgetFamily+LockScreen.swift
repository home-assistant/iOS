#if !os(watchOS)
import WidgetKit

public extension WidgetFamily {
    /// Whether the family lives on the lock screen, where the system draws everything over the
    /// wallpaper on its own background rather than on a card of ours.
    var isLockScreenAccessory: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait: return false
        @unknown default: return false
        }
    }
}
#endif
