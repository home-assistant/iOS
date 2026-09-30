import SFSafeSymbols
import Shared
import SwiftUI

/// Row used by every magic item configuration list: Watch, CarPlay, widgets and app icon shortcuts.
struct MagicItemConfigurationRow: View {
    private let item: MagicItem
    private let info: MagicItem.Info
    private let iconColor: UIColor?
    private let isReorderIndicatorVisible: Bool

    /// A nil `iconColor` lets the item's own customization decide, falling back to the app tint.
    /// A nil `info` means the item's information is not loaded yet, so its id stands in for its name.
    init(
        item: MagicItem,
        info: MagicItem.Info?,
        iconColor: UIColor? = nil,
        isReorderIndicatorVisible: Bool
    ) {
        self.item = item
        self.info = info ?? .init(id: item.id, name: item.id, iconName: "")
        self.iconColor = iconColor
        self.isReorderIndicatorVisible = isReorderIndicatorVisible
    }

    var body: some View {
        HStack {
            Image(uiImage: item.icon(info: info).image(
                ofSize: .init(width: 18, height: 18),
                color: resolvedIconColor
            ))
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                Text(item.name(info: info))
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isReorderIndicatorVisible {
                Image(systemSymbol: .line3Horizontal)
                    .foregroundStyle(.gray)
            }
        }
    }

    private var resolvedIconColor: UIColor {
        if let iconColor {
            return iconColor
        } else if let customIconColor = item.customization?.iconColor ?? info.customization?.iconColor {
            return .init(hex: customIconColor)
        } else {
            return .haPrimary
        }
    }

    /// An assist prompt shows the prompt it sends, everything else its Server • Area • Device line.
    private var subtitle: String? {
        if item.type == .assistPrompt,
           let assistPrompt = item.assistPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !assistPrompt.isEmpty {
            return assistPrompt
        } else {
            return info.contextSubtitle
        }
    }
}

#Preview {
    List {
        MagicItemConfigurationRow(
            item: .init(id: "light.kitchen", serverId: "1", type: .entity),
            info: .init(
                id: "1-light.kitchen",
                name: "Kitchen light",
                iconName: "mdi:lightbulb",
                contextSubtitle: "Home • Kitchen"
            ),
            isReorderIndicatorVisible: false
        )
        MagicItemConfigurationRow(
            item: .init(id: "light.kitchen", serverId: "1", type: .entity),
            info: .init(
                id: "1-light.kitchen",
                name: "Kitchen light",
                iconName: "mdi:lightbulb",
                contextSubtitle: "Home • Kitchen"
            ),
            isReorderIndicatorVisible: true
        )
    }
}
