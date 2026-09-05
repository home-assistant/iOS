#if !os(watchOS)
import HAIconic
import SwiftUI
import WidgetKit

/// The lock screen's circular accessory when nothing runs it in place: one Material Design glyph on
/// the system's accessory background, filling the slot the family gives it.
///
/// This is ``WidgetCircularAccessoryView`` with the glyph left as it is — for an accessory the
/// whole of which is a deep link (`widgetURL`), or an empty state that does nothing. An accessory
/// that runs an intent has to wrap the glyph in its button, and goes through
/// ``WidgetCircularAccessoryView`` directly so the button ends up in the right place.
public struct WidgetCircularIconView: View {
    private let icon: MaterialDesignIcons

    /// - Parameter icon: the glyph the accessory stands for.
    public init(icon: MaterialDesignIcons) {
        self.icon = icon
    }

    public var body: some View {
        WidgetCircularAccessoryView(icon: icon) { glyph in
            glyph
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
