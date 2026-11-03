#if !os(watchOS)
import SwiftUI

struct WidgetTileIconView: View {
    @Environment(\.widgetToggleColor) private var toggleColor

    let model: WidgetTileModel
    let sizeStyle: WidgetTileSizeStyle
    let rowHeight: CGFloat?

    var body: some View {
        let color = toggleColor ?? model.iconColor
        VStack {
            Text(verbatim: model.icon.unicode)
                .font(sizeStyle.iconFont(withBackground: model.showIconBackground, inRowOfHeight: rowHeight))
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: false)
                .accessibilityHidden(true)
        }
        .frame(
            width: sizeStyle.iconCircleSize(inRowOfHeight: rowHeight).width,
            height: sizeStyle.iconCircleSize(inRowOfHeight: rowHeight).height
        )
        .modify { view in
            if model.showIconBackground {
                view
                    .background(color.opacity(0.3))
                    .clipShape(Circle())
            } else {
                view
            }
        }
    }
}

#Preview {
    WidgetTileIconView(
        model: .init(id: "light", title: "Light", icon: .lightbulbIcon),
        sizeStyle: .regular,
        rowHeight: nil
    )
}
#endif
