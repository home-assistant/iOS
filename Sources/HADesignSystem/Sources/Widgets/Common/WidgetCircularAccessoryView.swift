#if !os(watchOS)
import HAIconic
import SwiftUI
import WidgetKit

/// The lock screen's circular accessory: one Material Design glyph on the system's accessory
/// background, filling the slot the family gives it — with the glyph handed back through `control`
/// so the widget can wrap it in whatever runs it.
///
/// The arrangement is the point. On the lock screen a widget's `Button` only runs its intent when
/// the tap lands on the button's own label; anything else in the slot is a plain tap, and a plain
/// tap on a lock screen widget launches the app. So the label is the glyph and nothing more, sized
/// to fill the whole slot, and the two things that are not a label — the system background and the
/// `GeometryReader` the glyph is measured from — sit around the control rather than inside it. With
/// the background and the reader inside the label, the scripts widget opened the app instead of
/// running the script (home-assistant/iOS#5642); the gauge widget, whose button wraps a plain
/// view, kept working.
///
/// The glyph is drawn through ``WidgetAccessoryIconView`` rather than as text in the icon font,
/// which is what makes it appear on a real lock screen at all, and the background is the system's
/// own so the accessory sits on the lock screen like every other circular widget instead of on a
/// colour of ours.
public struct WidgetCircularAccessoryView<Control: View>: View {
    /// Wraps the glyph in the control that runs it — or leaves it alone, for an accessory that is
    /// a deep link or nothing at all.
    public typealias ControlBuilder = (AnyView) -> Control

    /// The glyph's share of the accessory's diameter. Apple's circular accessories keep their
    /// figure around half the circle, which leaves the ring of breathing room the lock screen
    /// expects — and the slot is 72–76pt depending on the device, so the glyph is sized from what
    /// the family actually hands over rather than pinned to one number.
    private static var iconScale: CGFloat { 0.5 }

    private let icon: MaterialDesignIcons
    private let control: ControlBuilder

    /// - Parameters:
    ///   - icon: the glyph the accessory stands for.
    ///   - control: wraps the glyph, already sized to fill the slot, in the control that runs it.
    public init(icon: MaterialDesignIcons, @ViewBuilder control: @escaping ControlBuilder) {
        self.icon = icon
        self.control = control
    }

    public var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            ZStack {
                AccessoryWidgetBackground()
                control(AnyView(glyph(diameter: diameter)))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(Circle())
        }
    }

    /// The glyph, taking the whole slot so that the control wrapping it is the whole slot too:
    /// there is no corner of the accessory a tap can land on that is not the control.
    private func glyph(diameter: CGFloat) -> some View {
        WidgetAccessoryIconView(icon: icon, size: (diameter * Self.iconScale).rounded())
            .foregroundStyle(.primary)
            // The glyph is the widget's identity, not a reading of the user's, and a circular
            // accessory has nothing else in it — redacted away, it leaves the widget picker
            // showing a blank disc.
            .unredacted()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}

#Preview {
    HStack {
        WidgetCircularAccessoryView(icon: .scriptTextIcon) { glyph in
            Button {} label: { glyph }
                .buttonStyle(.plain)
        }
        WidgetCircularAccessoryView(icon: .coffeeIcon) { glyph in glyph }
    }
    .frame(height: 76)
}
#endif
