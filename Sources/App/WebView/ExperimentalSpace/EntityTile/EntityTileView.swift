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
    let haEntity: HAEntity

    @Namespace private var namespace
    @State private var triggerHaptic = 0
    @State private var iconColor: Color = .secondary
    @State private var showMoreInfoDialog = false

    init(server: Server, haEntity: HAEntity) {
        self.server = server
        self.haEntity = haEntity
    }

    var body: some View {
        tileContent
            .frame(height: Constants.tileHeight)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
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
            .matchedTransitionSource(id: haEntity.entityId, in: namespace)
            .onTapGesture {
                showMoreInfoDialog = true
            }
            .fullScreenCover(isPresented: $showMoreInfoDialog) {
                EntityMoreInfoDialogView(
                    server: server, haEntity: haEntity
                )
                .navigationTransition(.zoom(sourceID: haEntity.entityId, in: namespace))
            }
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            contentRow
                .padding([.leading, .trailing], DesignSystem.Spaces.oneAndHalf)
        }
    }

    private var contentRow: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spaces.oneAndHalf) {
            iconView
            entityInfoStack
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var entityInfoStack: some View {
        VStack(alignment: .leading, spacing: Constants.textVStackSpacing) {
            entityNameText
            entityStateText
        }
    }

    private var entityNameText: some View {
        Text(haEntity.attributes.friendlyName ?? haEntity.entityId)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(Color(uiColor: .label))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    private var entityStateText: some View {
        Text(
            Domain(entityId: haEntity.entityId)?.contextualStateDescription(for: haEntity) ?? haEntity.state
        )
        .font(.caption)
        .foregroundColor(Color(uiColor: .secondaryLabel))
    }

    private var iconView: some View {
        let icon: MaterialDesignIcons
        if let entityIcon = haEntity.attributes.icon {
            icon = MaterialDesignIcons(serversideValueNamed: entityIcon)
        } else if let domain = Domain(entityId: haEntity.entityId) {
            let deviceClass = DeviceClassProvider.deviceClass(
                for: haEntity.entityId,
                serverId: server.identifier.rawValue
            )
            let stateString = haEntity.state
            let domainState = Domain.State(rawValue: stateString) ?? .unknown
            icon = domain.icon(deviceClass: deviceClass.rawValue, state: domainState)
        } else {
            icon = .homeIcon
        }

        return Button(intent: AppIntentProvider.intent(for: haEntity, server: server)) {
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
