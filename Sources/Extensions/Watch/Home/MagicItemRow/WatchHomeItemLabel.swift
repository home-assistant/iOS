import Shared
import SwiftUI

/// Shared layout for a watch home item row: a circular glass icon, a bold name with an optional
/// subtitle, and an optional trailing accessory (e.g. a chevron for folders). Keeps `WatchMagicViewRow`
/// and `WatchFolderRow` visually identical.
struct WatchHomeItemLabel<Icon: View, Accessory: View>: View {
    let name: String
    let subtitle: String?
    let textColor: Color
    let icon: Icon
    let accessory: Accessory

    init(
        name: String,
        subtitle: String? = nil,
        textColor: Color,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.name = name
        self.subtitle = subtitle
        self.textColor = textColor
        self.icon = icon()
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            icon
            VStack(alignment: .leading, spacing: .zero) {
                Text(name)
                    .font(.body.bold())
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            accessory
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, DesignSystem.Spaces.one)
        .padding(.trailing, DesignSystem.Spaces.one)
        .padding(.vertical, DesignSystem.Spaces.half)
    }
}

extension View {
    /// The 38pt circular glass (watchOS 26) / translucent-circle (legacy) container for a watch home
    /// row's leading icon. Apply to the icon content (image or state view).
    @ViewBuilder
    func watchRowIconContainer(color: UIColor) -> some View {
        frame(width: 38, height: 38)
            .modify { view in
                if #available(watchOS 26.0, *) {
                    view.glassEffect(.clear.tint(Color(uiColor: color).opacity(0.3)), in: .circle)
                } else {
                    view
                        .background(Color(uiColor: color).opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .padding([.vertical, .trailing], DesignSystem.Spaces.half)
    }
}
