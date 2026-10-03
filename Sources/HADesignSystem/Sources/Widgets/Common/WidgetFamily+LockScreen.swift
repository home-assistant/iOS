#if !os(watchOS)
import WidgetKit

public extension WidgetFamily {
    /// Whether the family lives on the lock screen, where the system draws everything over the
    /// wallpaper on its own background rather than on a card of ours.
    var isLockScreenAccessory: Bool {
        switch self {
        #if !os(macOS)
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
        #endif
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait: return false
        @unknown default: return false
        }
    }

    /// Whether this is the circular lock screen accessory. The lock screen families do not exist on
    /// macOS, so a comparison against the case itself would not compile there.
    var isAccessoryCircular: Bool {
        #if os(macOS)
        return false
        #else
        return self == .accessoryCircular
        #endif
    }

    /// Whether this is the rectangular lock screen accessory. See ``isAccessoryCircular``.
    var isAccessoryRectangular: Bool {
        #if os(macOS)
        return false
        #else
        return self == .accessoryRectangular
        #endif
    }

    /// Whether this is the inline lock screen accessory. See ``isAccessoryCircular``.
    var isAccessoryInline: Bool {
        #if os(macOS)
        return false
        #else
        return self == .accessoryInline
        #endif
    }
}
#endif
