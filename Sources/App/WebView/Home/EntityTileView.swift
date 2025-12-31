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
    @State private var cachedColorMode: String?
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
                .onTapGesture {
                    updateIconColor()
                }
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
        .sensoryFeedback(.success, trigger: triggerHaptic)
    }

    private func updateIconColor() {
        guard let haEntity, haEntity.state == Domain.State.on.rawValue else {
            iconColor = .secondary
            return
        }
        
        // Get current color_mode from entity attributes
        let currentColorMode = haEntity.attributes["color_mode"] as? String
        
        // Determine which color mode to use
        let colorModeToUse: String?
        if let currentColorMode {
            // Cache the current color mode for future use
            cachedColorMode = currentColorMode
            colorModeToUse = currentColorMode
        } else if let cachedColorMode {
            // Use cached color mode if current is nil and cache exists
            colorModeToUse = cachedColorMode
        } else {
            // Both current and cached are nil, use nil
            colorModeToUse = nil
        }
        
        // Check color_mode first if available to prioritize the correct attribute
        if let colorMode = colorModeToUse {
            switch colorMode {
            case "rgb", "rgbw", "rgbww":
                if let rgb = haEntity.attributes["rgb_color"] as? [Int], rgb.count == 3 {
                    iconColor = Color(
                        red: Double(rgb[0]) / 255.0,
                        green: Double(rgb[1]) / 255.0,
                        blue: Double(rgb[2]) / 255.0
                    )
                    return
                }
            case "hs":
                if let hs = haEntity.attributes["hs_color"] as? [Double], hs.count == 2 {
                    iconColor = Color(hue: hs[0] / 360.0, saturation: hs[1] / 100.0, brightness: 1.0)
                    return
                }
            case "xy":
                // Home Assistant usually provides rgb_color approximation for xy
                if let rgb = haEntity.attributes["rgb_color"] as? [Int], rgb.count == 3 {
                    iconColor = Color(
                        red: Double(rgb[0]) / 255.0,
                        green: Double(rgb[1]) / 255.0,
                        blue: Double(rgb[2]) / 255.0
                    )
                    return
                }
            case "color_temp":
                // Home Assistant usually provides rgb_color approximation for color_temp
                if let rgb = haEntity.attributes["rgb_color"] as? [Int], rgb.count == 3 {
                    iconColor = Color(
                        red: Double(rgb[0]) / 255.0,
                        green: Double(rgb[1]) / 255.0,
                        blue: Double(rgb[2]) / 255.0
                    )
                    return
                }
            default:
                break
            }
        }

        // Fallback or if color_mode is missing
        if let rgb = haEntity.attributes["rgb_color"] as? [Int], rgb.count == 3 {
            iconColor = Color(red: Double(rgb[0]) / 255.0, green: Double(rgb[1]) / 255.0, blue: Double(rgb[2]) / 255.0)
            return
        }

        if let hs = haEntity.attributes["hs_color"] as? [Double], hs.count == 2 {
            iconColor = Color(hue: hs[0] / 360.0, saturation: hs[1] / 100.0, brightness: 1.0)
            return
        }

        iconColor = .yellow
    }
}
