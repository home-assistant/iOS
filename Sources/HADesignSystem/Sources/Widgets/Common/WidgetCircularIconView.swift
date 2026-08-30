#if !os(watchOS)
import HAIconic
import SwiftUI
import WidgetKit

/// The lock screen's circular accessory: one Material Design glyph on the system's accessory
/// background, filling the slot the family gives it.
///
/// The glyph is drawn through ``WidgetAccessoryIconView`` rather than as text in the icon font,
/// which is what makes it appear on a real lock screen at all, and the background is the system's
/// own so the accessory sits on the lock screen like every other circular widget instead of on a
/// colour of ours.
public struct WidgetCircularIconView: View {
    /// The glyph's share of the accessory's diameter. Apple's circular accessories keep their
    /// figure around half the circle, which leaves the ring of breathing room the lock screen
    /// expects — and the slot is 72–76pt depending on the device, so the glyph is sized from what
    /// the family actually hands over rather than pinned to one number.
    private static let iconScale: CGFloat = 0.5

    private let icon: MaterialDesignIcons

    /// - Parameter icon: the glyph the accessory stands for.
    public init(icon: MaterialDesignIcons) {
        self.icon = icon
    }

    public var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            ZStack {
                AccessoryWidgetBackground()
                WidgetAccessoryIconView(icon: icon, size: (diameter * Self.iconScale).rounded())
                    .foregroundStyle(.primary)
                    // The glyph is the widget's identity, not a reading of the user's, and a
                    // circular accessory has nothing else in it — redacted away, it leaves the
                    // widget picker showing a blank disc.
                    .unredacted()
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(Circle())
        }
    }
}

#Preview {
    HStack {
        WidgetCircularIconView(icon: .scriptTextIcon)
        WidgetCircularIconView(icon: .coffeeIcon)
        WidgetCircularIconView(icon: .lightbulbIcon)
    }
    .frame(height: 76)
}
#endif
