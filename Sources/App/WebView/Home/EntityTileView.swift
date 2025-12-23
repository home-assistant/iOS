import Shared
import SwiftUI

private enum Constants {
    static let tileHeight: CGFloat = 65
    static let cornerRadius: CGFloat = 14
    static let iconSize: CGFloat = 38
    static let iconFontSize: CGFloat = 20
    static let iconOpacity: CGFloat = 0.3
    static let borderLineWidth: CGFloat = 1
    static let textVStackSpacing: CGFloat = 2
}

struct EntityTileView: View {
    struct State {
        let value: String
        let iconColor: Color
    }

    let entity: HAAppEntity
    let state: State?

    init(entity: HAAppEntity, state: State? = nil) {
        self.entity = entity
        self.state = state
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
                iconView
                VStack(alignment: .leading, spacing: Constants.textVStackSpacing) {
                    Text(entity.name)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(uiColor: .label))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let state {
                        Text(state.value)
                            .font(.caption)
                            .foregroundColor(Color(uiColor: .secondaryLabel))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding([.leading, .trailing], DesignSystem.Spaces.oneAndHalf)
        }
        .frame(height: Constants.tileHeight)
        .frame(maxWidth: .infinity)
        .background(Color.tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(Color.tileBorder, lineWidth: Constants.borderLineWidth)
        )
    }

    private var iconView: some View {
        let icon = entity.icon.flatMap { MaterialDesignIcons(serversideValueNamed: $0) } ?? .homeIcon
        let iconColor = state?.iconColor ?? Color.haPrimary

        return VStack {
            Text(verbatim: icon.unicode)
                .font(.custom(MaterialDesignIcons.familyName, size: Constants.iconFontSize))
                .foregroundColor(iconColor)
                .fixedSize(horizontal: false, vertical: false)
        }
        .frame(width: Constants.iconSize, height: Constants.iconSize)
        .background(iconColor.opacity(Constants.iconOpacity))
        .clipShape(Circle())
    }
}

#Preview {
    EntityTileView(entity: HAAppEntity(
        id: "preview_id",
        entityId: "light.living_room",
        serverId: "preview_server",
        domain: "light",
        name: "Living Room Light",
        icon: "mdi:lightbulb",
        rawDeviceClass: nil
    ), state: .init(value: "On", iconColor: .yellow))
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
