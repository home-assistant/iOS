import HADesignSystem
import SFSafeSymbols
import Shared
import SwiftUI

/// The card Siri and the Shortcuts app show under the spoken answer of `GetEntityStateAppIntent`.
@available(macOS 13.0, *)
struct EntityStateSnippetView: View {
    let state: HAEntityStateAppEntity

    private static let iconSize: CGFloat = 40

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            icon
                .frame(width: Self.iconSize, height: Self.iconSize)
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(state.name)
                    .font(.headline)
                Text(state.formattedState)
                    .font(.title3)
                    .fontWeight(.semibold)
                if let context {
                    Text(context)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spaces.two)
    }

    /// The frontend's state color, so the card reads the same as the dashboard.
    private var iconColor: Color {
        EntityStateColor.color(domain: state.domain, deviceClass: state.deviceClass, state: state.state) ?? .secondary
    }

    @ViewBuilder
    private var icon: some View {
        if let image = MaterialDesignIcons.pngData(forServersideValue: state.iconName).flatMap(UIImage.init(data:)) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(iconColor)
        } else {
            Image(systemSymbol: SFSymbol(rawValue: state.iconName))
                .resizable()
                .scaledToFit()
                .foregroundStyle(iconColor)
        }
    }

    /// `Floor • Area • Device`, whichever of the three are known.
    private var context: String? {
        [state.floorName, state.areaName, state.deviceName]
            .compactMap { $0 }
            .joined(separator: " • ")
            .nilIfEmpty
    }
}

@available(macOS 13.0, *)
extension HAEntityStateAppEntity {
    /// A sample light for the preview.
    static var previewLight: HAEntityStateAppEntity {
        var state = HAEntityStateAppEntity()
        state.name = "Kitchen ceiling"
        state.entityId = "light.kitchen_ceiling"
        state.domain = "light"
        state.state = "on"
        state.formattedState = "On"
        state.isActive = true
        state.areaName = "Kitchen"
        state.floorName = "Ground floor"
        state.serverName = "Home"
        state.attributes = "{\"brightness\":200}"
        state.iconName = "mdi:ceiling-light"
        return state
    }
}

@available(macOS 13.0, *)
#Preview {
    EntityStateSnippetView(state: .previewLight)
}
