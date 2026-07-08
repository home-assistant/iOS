import SFSafeSymbols
import Shared
import SwiftUI

struct WatchFolderRow: View {
    let item: MagicItem
    let itemInfo: MagicItem.Info
    var layout: WatchLayout = .list
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            label
        }
        .modify { view in
            if layout == .grid {
                view.watchHomeItemGridStyle(tint: backgroundForWatchItem)
            } else {
                view
                    .frame(maxWidth: .infinity)
                    .watchHomeItemRowStyle(tint: backgroundForWatchItem)
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if layout == .grid {
            gridIcon
        } else {
            WatchHomeItemLabel(
                name: item.name(info: itemInfo),
                textColor: textColor,
                icon: { iconView },
                accessory: {
                    Image(systemSymbol: .chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            )
        }
    }

    private var iconColor: UIColor {
        if let hex = item.customization?.iconColor {
            .init(hex: hex)
        } else {
            .white
        }
    }

    private var iconView: some View {
        VStack {
            Image(uiImage: item.icon(info: itemInfo).image(
                ofSize: .init(width: 24, height: 24),
                color: iconColor
            ))
            .foregroundStyle(Color(uiColor: iconColor))
            .padding()
        }
        .watchRowIconContainer(color: iconColor)
    }

    private var gridIcon: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: item.icon(info: itemInfo).image(
                ofSize: .init(width: 28, height: 28),
                color: iconColor
            ))
            .foregroundStyle(Color(uiColor: iconColor))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Image(systemSymbol: .chevronRight)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(DesignSystem.Spaces.half)
        }
        .contentShape(Rectangle())
    }

    private var textColor: Color {
        if let textColor = item.customization?.textColor {
            .init(uiColor: .init(hex: textColor))
        } else {
            .white
        }
    }

    private var backgroundForWatchItem: Color? {
        if let backgroundColor = item.customization?.backgroundColor {
            Color(uiColor: .init(hex: backgroundColor))
        } else {
            nil
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    return List {
        WatchFolderRow(
            item: .init(
                id: "folder1",
                serverId: "",
                type: .folder,
                customization: .init(iconColor: "#03A9F4"),
                displayText: "Living Room"
            ),
            itemInfo: .init(
                id: "folder1",
                name: "Living Room",
                iconName: "mdi:folder",
                customization: .init(iconColor: "#03A9F4")
            )
        ) {}
    }
}
