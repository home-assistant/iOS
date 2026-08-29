#if !os(watchOS)
import HAIconic
import SwiftUI

/// A Material Design glyph drawn as an image, for the lock screen families.
///
/// Everywhere else a glyph is `Text` in the icon font, which is lighter and follows the layout's
/// type. The lock screen cannot use that: WidgetKit archives the widget's view tree and the system
/// draws it outside the extension, where a font the extension registered at runtime does not exist.
/// The glyph then comes out as a missing character — which is why every icon based lock screen
/// widget (actions, scripts, open page, assist) rendered blank on device while the gauge and details
/// ones, drawn with system text, kept working, and why none of it reproduces in the simulator.
///
/// Rasterizing the glyph keeps the drawing inside the extension, where the font is registered, and
/// hands the system a bitmap it can always draw. The image is a template, so the lock screen's
/// vibrant and accented rendering tints it the way it tints everything else.
public struct WidgetAccessoryIconView: View {
    private let icon: MaterialDesignIcons
    private let size: CGFloat

    /// - Parameters:
    ///   - icon: the glyph to draw.
    ///   - size: the square the glyph is drawn in, in points. The icon font's line box is exactly
    ///     one em, so the glyph fills the square without being clipped.
    public init(icon: MaterialDesignIcons, size: CGFloat) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        Image(uiImage: icon.image(ofSize: .init(width: size, height: size), color: .white))
            .renderingMode(.template)
            .frame(width: size, height: size)
            // The glyph stands for the widget's own title, which is announced already, and a
            // private-use character gives VoiceOver nothing to read anyway.
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        WidgetAccessoryIconView(icon: .scriptTextIcon, size: 36)
        WidgetAccessoryIconView(icon: .coffeeIcon, size: 36)
        WidgetAccessoryIconView(icon: .lightbulbIcon, size: 36)
    }
    .foregroundStyle(.primary)
}
#endif
