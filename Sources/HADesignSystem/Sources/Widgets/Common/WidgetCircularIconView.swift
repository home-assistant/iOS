#if !os(watchOS)
import HAIconic
import SwiftUI

/// The lock screen's circular accessory: one Material Design glyph over the Home Assistant mark,
/// on the system's dimmed circular background.
public struct WidgetCircularIconView: View {
    private let icon: MaterialDesignIcons
    private let logo: Image?

    /// - Parameters:
    ///   - icon: the glyph the accessory stands for.
    ///   - logo: the small mark under the glyph. The design system ships no assets of its own, so
    ///     the app hands its own logo in; `nil` leaves the glyph on its own.
    public init(icon: MaterialDesignIcons, logo: Image? = nil) {
        self.icon = icon
        self.logo = logo
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: icon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: 24))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
            if let logo {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 10, height: 10)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Circle())
    }
}

#Preview {
    HStack {
        WidgetCircularIconView(icon: .scriptTextIcon)
        WidgetCircularIconView(icon: .coffeeIcon)
        WidgetCircularIconView(icon: .lightbulbIcon)
    }
}
#endif
