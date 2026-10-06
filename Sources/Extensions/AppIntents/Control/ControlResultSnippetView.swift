import HADesignSystem
import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

/// The card Siri shows after a control command has changed something.
///
/// Sibling of `EntityStateSnippetView`, which answers a *question* and so colors the icon by state
/// the way the frontend does. This one reports an *action*, and is tinted Home Assistant blue
/// throughout rather than borrowing the amber a lit light carries — that yellow reads as Apple's
/// Home app, and this card should read as Home Assistant.
@available(macOS 13.0, *)
struct ControlResultSnippetView: View {
    let state: HAEntityStateAppEntity

    private static let iconSize: CGFloat = 28
    private var accent: Color { Color(uiColor: AppConstants.tintColor) }

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            icon
                .foregroundStyle(accent)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .padding(DesignSystem.Spaces.one)
                .background(accent.opacity(0.15), in: Circle())

            // Siri gives a snippet the full width of its own card and scales the type up with it,
            // so the sizes here sit a step below what the same rows would use in the app.
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(state.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(state.formattedState)
                    .font(.subheadline)
                    .foregroundStyle(accent)
                    .lineLimit(1)
                if let context {
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spaces.two)
    }

    /// The icon is a Material Design name, an SF Symbol name, or something neither renders.
    @ViewBuilder
    private var icon: some View {
        if let image = MaterialDesignIcons.pngData(forServersideValue: state.iconName)
            .flatMap(UIImage.init(data:)) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else if let symbol = UIImage(systemName: state.iconName) {
            Image(uiImage: symbol)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemSymbol: .powerCircleFill)
                .resizable()
                .scaledToFit()
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
#Preview {
    ControlResultSnippetView(state: .init())
}
