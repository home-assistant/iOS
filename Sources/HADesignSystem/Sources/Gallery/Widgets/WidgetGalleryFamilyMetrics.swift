#if !os(watchOS)
import Foundation
import WidgetKit

/// How big each widget family is on screen, and what to call it.
///
/// WidgetKit never hands a widget its size, so a gallery outside a widget extension has to state it.
/// These are the iPhone measurements — the point of the gallery is to see a component at the size it
/// really has to work in, not at whatever a list row leaves over.
public enum WidgetGalleryFamilyMetrics {
    public static func size(for family: WidgetFamily) -> CGSize {
        switch family {
        case .systemSmall: return .init(width: 158, height: 158)
        case .systemMedium: return .init(width: 338, height: 158)
        case .systemLarge: return .init(width: 338, height: 354)
        case .accessoryCircular: return .init(width: 76, height: 76)
        case .accessoryRectangular: return .init(width: 172, height: 76)
        case .accessoryInline: return .init(width: 240, height: 26)
        default: return .init(width: 338, height: 354)
        }
    }

    public static func cornerRadius(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .accessoryCircular: return size(for: family).width / 2
        case .accessoryInline: return DesignSystem.CornerRadius.one
        case .accessoryRectangular: return DesignSystem.CornerRadius.two
        default: return DesignSystem.CornerRadius.three
        }
    }

    /// Whether the family lives on the lock screen, where the system renders everything on a dark,
    /// desaturated backdrop rather than on a card.
    public static func isAccessory(_ family: WidgetFamily) -> Bool {
        family.isLockScreenAccessory
    }

    public static func title(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall: return "Small"
        case .systemMedium: return "Medium"
        case .systemLarge: return "Large"
        case .accessoryCircular: return "Lock screen · Circular"
        case .accessoryRectangular: return "Lock screen · Rectangular"
        case .accessoryInline: return "Lock screen · Inline"
        default: return "Extra large"
        }
    }
}
#endif
