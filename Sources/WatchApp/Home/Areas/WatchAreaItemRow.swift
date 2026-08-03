import SFSafeSymbols
import Shared
import SwiftUI

/// A configured area entry (`MagicItem` of type `.area`) on the home screen or inside a folder.
/// It renders and behaves exactly like the automatic area rows (`WatchAreaRow`) — circular icon,
/// chevron, push to the area's entities — while honouring the name, icon and colors the user set
/// on the item. Renders as an icon-only tile in the grid layout, matching `WatchFolderRow`.
struct WatchAreaItemRow: View {
    let item: MagicItem
    let itemInfo: MagicItem.Info
    /// The server the area belongs to, shown under its name only when the configuration spans more
    /// than one server (resolved by `WatchHomeViewModel.serverName(for:)`).
    var subtitle: String? = nil
    var layout: WatchLayout = .list
    @Environment(\.watchNavigate) private var navigate

    var body: some View {
        Button {
            navigate(.areaEntities(areaId: item.id, serverId: item.serverId))
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
            Image(uiImage: icon.image(
                ofSize: .init(width: 28, height: 28),
                color: iconColor
            ))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(item.name(info: itemInfo)))
        } else {
            WatchHomeItemLabel(
                name: item.name(info: itemInfo),
                subtitle: subtitle,
                textColor: textColor,
                icon: {
                    VStack {
                        Image(uiImage: icon.image(
                            ofSize: .init(width: 24, height: 24),
                            color: iconColor
                        ))
                        .padding()
                    }
                    .watchRowIconContainer(color: iconColor)
                },
                accessory: {
                    Image(systemSymbol: .chevronRight)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            )
        }
    }

    private var icon: MaterialDesignIcons {
        item.icon(info: itemInfo)
    }

    private var iconColor: UIColor {
        if let hex = item.customization?.iconColor {
            .init(hex: hex)
        } else {
            .white
        }
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

#Preview("List") {
    MaterialDesignIcons.register()
    return List {
        WatchAreaItemRow(
            item: .init(id: "living_room", serverId: "1", type: .area),
            itemInfo: .init(id: "1-living_room", name: "Living Room", iconName: "mdi:sofa")
        )
        WatchAreaItemRow(
            item: .init(id: "kitchen", serverId: "2", type: .area),
            itemInfo: .init(id: "2-kitchen", name: "Kitchen", iconName: ""),
            subtitle: "Beach house"
        )
    }
}

#Preview("Grid") {
    MaterialDesignIcons.register()
    return List {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 60), spacing: DesignSystem.Spaces.one)],
            spacing: DesignSystem.Spaces.one
        ) {
            WatchAreaItemRow(
                item: .init(id: "living_room", serverId: "1", type: .area),
                itemInfo: .init(id: "1-living_room", name: "Living Room", iconName: "mdi:sofa"),
                layout: .grid
            )
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}
