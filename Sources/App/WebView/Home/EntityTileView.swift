import Shared
import SwiftUI

@available(iOS 26.0, *)
struct EntityTileView: View {
    enum Constants {
        static let tileHeight: CGFloat = 65
        static let cornerRadius: CGFloat = 14
        static let iconSize: CGFloat = 38
        static let iconFontSize: CGFloat = 20
        static let iconOpacity: CGFloat = 0.3
        static let borderLineWidth: CGFloat = 1
        static let textVStackSpacing: CGFloat = 2
    }

    let entity: HAAppEntity
    let state: String?
    let attributes: [String: Any]

    init(entity: HAAppEntity, state: String? = nil, attributes: [String: Any] = [:]) {
        self.entity = entity
        self.state = state
        self.attributes = attributes
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
                        Text(state)
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
        let icon: MaterialDesignIcons
        if let entityIcon = entity.icon {
            icon = MaterialDesignIcons(serversideValueNamed: entityIcon)
        } else if let domain = Domain(entityId: entity.entityId) {
            let deviceClass = attributes["device_class"] as? String
            let stateString = state ?? ""
            // Attempt to map string state to Domain.State, fallback to unknown if fails
            // Since Domain.State is backed by String, we can try rawValue init
            // Note: Domain.State cases are lowercased generally, but we should be careful with casing
            // However Domain.State is used in Domain.icon(deviceClass:state:)
            // We need to see if we can convert string state to Domain.State
            // Domain.State.init(rawValue:) will work if the strings match exactly
            
            let domainState = Domain.State(rawValue: stateString) ?? .unknown
            icon = domain.icon(deviceClass: deviceClass, state: domainState)
        } else {
            icon = .homeIcon
        }
        
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

    private var iconColor: Color {
        guard let state else { return Color.haPrimary }
        guard state == "on" else { return .secondary }
        
        // Check color_mode first if available to prioritize the correct attribute
        if let colorMode = attributes["color_mode"] as? String {
            switch colorMode {
            case "rgb", "rgbw", "rgbww":
                if let rgb = attributes["rgb_color"] as? [Int], rgb.count == 3 {
                    return Color(red: Double(rgb[0])/255.0, green: Double(rgb[1])/255.0, blue: Double(rgb[2])/255.0)
                }
            case "hs":
                if let hs = attributes["hs_color"] as? [Double], hs.count == 2 {
                    return Color(hue: hs[0]/360.0, saturation: hs[1]/100.0, brightness: 1.0)
                }
            case "xy":
                // Home Assistant usually provides rgb_color approximation for xy
                if let rgb = attributes["rgb_color"] as? [Int], rgb.count == 3 {
                    return Color(red: Double(rgb[0])/255.0, green: Double(rgb[1])/255.0, blue: Double(rgb[2])/255.0)
                }
            case "color_temp":
                // Home Assistant usually provides rgb_color approximation for color_temp
                if let rgb = attributes["rgb_color"] as? [Int], rgb.count == 3 {
                    return Color(red: Double(rgb[0])/255.0, green: Double(rgb[1])/255.0, blue: Double(rgb[2])/255.0)
                }
            default:
                break
            }
        }
        
        // Fallback or if color_mode is missing
        if let rgb = attributes["rgb_color"] as? [Int], rgb.count == 3 {
            return Color(red: Double(rgb[0])/255.0, green: Double(rgb[1])/255.0, blue: Double(rgb[2])/255.0)
        }
        
        if let hs = attributes["hs_color"] as? [Double], hs.count == 2 {
            return Color(hue: hs[0]/360.0, saturation: hs[1]/100.0, brightness: 1.0)
        }
        
        return .yellow
    }
}
@available(iOS 26.0, *)
#Preview {
    EntityTileView(entity: HAAppEntity(
        id: "preview_id",
        entityId: "light.living_room",
        serverId: "preview_server",
        domain: "light",
        name: "Living Room Light",
        icon: "mdi:lightbulb",
        rawDeviceClass: nil
    ), state: "on", attributes: ["rgb_color": [255, 0, 0], "color_mode": "rgb"])
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
