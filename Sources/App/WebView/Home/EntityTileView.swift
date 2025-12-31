import AppIntents
import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
struct EntityTileView: View {
    enum Constants {
        static let tileHeight: CGFloat = 65
        static let cornerRadius: CGFloat = 16
        static let iconSize: CGFloat = 38
        static let iconFontSize: CGFloat = 20
        static let iconOpacity: CGFloat = 0.3
        static let borderLineWidth: CGFloat = 1
        static let textVStackSpacing: CGFloat = 2
    }

    let server: Server
    let appEntity: HAAppEntity
    let haEntity: HAEntity?

    @State private var triggerHaptic = 0
    @State private var iconColor: Color = .secondary

    init(server: Server, appEntity: HAAppEntity, haEntity: HAEntity?) {
        self.server = server
        self.appEntity = appEntity
        self.haEntity = haEntity
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
                iconView
                VStack(alignment: .leading, spacing: Constants.textVStackSpacing) {
                    Text(appEntity.name)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(uiColor: .label))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let haEntity {
                        Text(
                            Domain(entityId: appEntity.entityId)?.contextualStateDescription(for: haEntity) ?? haEntity
                                .state
                        )
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
        .glassEffect(
            .clear.interactive(),
            in: RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
        )
        .onChange(of: haEntity) { _, _ in
            updateIconColor()
        }
        .onAppear {
            updateIconColor()
        }
    }

    private var iconView: some View {
        let icon: MaterialDesignIcons
        if let entityIcon = appEntity.icon {
            icon = MaterialDesignIcons(serversideValueNamed: entityIcon)
        } else if let domain = Domain(entityId: appEntity.entityId) {
            let deviceClass = haEntity?.attributes["device_class"] as? String
            let stateString = haEntity?.state
            let domainState = Domain.State(rawValue: stateString ?? "") ?? .unknown
            icon = domain.icon(deviceClass: deviceClass, state: domainState)
        } else {
            icon = .homeIcon
        }

        return Button(intent: AppIntentProvider.intent(for: appEntity, server: server)) {
            VStack {
                Text(verbatim: icon.unicode)
                    .font(.custom(MaterialDesignIcons.familyName, size: Constants.iconFontSize))
                    .foregroundColor(iconColor)
                    .fixedSize(horizontal: false, vertical: false)
            }
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(iconColor.opacity(Constants.iconOpacity))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                triggerHaptic += 1
            }
        )
        .sensoryFeedback(.impact, trigger: triggerHaptic)
    }

    private func updateIconColor() {
        guard let haEntity else {
            iconColor = .secondary
            return
        }

        let state = haEntity.state
        let colorMode = haEntity.attributes["color_mode"] as? String
        let rgbColor = haEntity.attributes["rgb_color"] as? [Int]
        let hsColor = haEntity.attributes["hs_color"] as? [Double]

        iconColor = EntityIconColorProvider.iconColor(
            state: state,
            colorMode: colorMode,
            rgbColor: rgbColor,
            hsColor: hsColor
        )
    }
}
